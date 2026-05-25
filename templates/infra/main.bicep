// AI App Factory — Bicep starter
//
// Deploys the factory's default Azure footprint:
//   - Log Analytics workspace + Application Insights
//   - Storage account (Functions backend)
//   - App Service Plan (Linux, Consumption Y1)
//   - Function App with system-assigned managed identity
//   - Static Web App (frontend)
//   - Key Vault with RBAC, managed-identity read access for the Function App
//
// Database is intentionally not included. Add the right module for the
// project's choice (Azure SQL, Cosmos DB, PostgreSQL) once the architecture
// fixes that decision; an ADR should explain the choice.
//
// Conventions:
//   - All resource names are derived from `appName` + `env` + a short uniqueString
//     to avoid global-namespace collisions.
//   - Managed identity is preferred over connection strings wherever Azure supports it.
//   - Diagnostic settings route to Application Insights / Log Analytics.

targetScope = 'resourceGroup'

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------

@description('Short application name. Lowercase, 3-15 chars. Used as the prefix for every resource name.')
@minLength(3)
@maxLength(15)
param appName string

@description('Environment label. One of: dev, staging, prod.')
@allowed([
  'dev'
  'staging'
  'prod'
])
param env string

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Tags applied to every resource.')
param tags object = {
  app: appName
  env: env
  managedBy: 'bicep'
}

@description('Frontend allowed origin (for CORS on the Function App).')
param allowedOrigin string

// ---------------------------------------------------------------------------
// Derived names
// ---------------------------------------------------------------------------

var suffix = uniqueString(resourceGroup().id, appName, env)
var baseName = '${appName}-${env}'

var logAnalyticsName = '${baseName}-log'
var appInsightsName = '${baseName}-ai'
var storageName = toLower('st${replace(appName, '-', '')}${env}${take(suffix, 6)}')
var planName = '${baseName}-plan'
var functionAppName = '${baseName}-fn-${take(suffix, 6)}'
var staticSiteName = '${baseName}-web'
var keyVaultName = 'kv-${baseName}-${take(suffix, 6)}'

// ---------------------------------------------------------------------------
// Log Analytics + Application Insights
// ---------------------------------------------------------------------------

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    workspaceCapping: {
      dailyQuotaGb: 1
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// ---------------------------------------------------------------------------
// Storage account (Function App backend)
// ---------------------------------------------------------------------------

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
  }
}

// ---------------------------------------------------------------------------
// App Service Plan (Consumption Y1 for Functions)
// ---------------------------------------------------------------------------

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  tags: tags
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    reserved: true // Linux
  }
}

// ---------------------------------------------------------------------------
// Function App with managed identity
// ---------------------------------------------------------------------------

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'NODE|20'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      cors: {
        allowedOrigins: [
          allowedOrigin
        ]
        supportCredentials: false
      }
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~20'
        }
        {
          name: 'AzureWebJobsStorage__accountName'
          value: storage.name
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'AZURE_KEY_VAULT_URL'
          value: 'https://${keyVaultName}${environment().suffixes.keyvaultDns}/'
        }
        {
          name: 'APP_ENV'
          value: env
        }
        {
          name: 'ALLOWED_ORIGIN'
          value: allowedOrigin
        }
      ]
    }
  }
}

// Grant the Function App's managed identity the role needed to use storage with AAD auth.
resource storageBlobOwnerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, functionApp.id, 'StorageBlobDataOwner')
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b')
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ---------------------------------------------------------------------------
// Static Web App (frontend)
// ---------------------------------------------------------------------------

resource staticSite 'Microsoft.Web/staticSites@2023-12-01' = {
  name: staticSiteName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    allowConfigFileUpdates: true
    stagingEnvironmentPolicy: 'Enabled'
  }
}

// ---------------------------------------------------------------------------
// Key Vault with RBAC + managed-identity read access for the Function App
// ---------------------------------------------------------------------------

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: env == 'prod' ? true : null
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

resource kvSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, functionApp.id, 'KeyVaultSecretsUser')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------

output functionAppName string = functionApp.name
output functionAppHostName string = functionApp.properties.defaultHostName
output staticSiteName string = staticSite.name
output staticSiteDefaultHostname string = staticSite.properties.defaultHostname
output keyVaultUri string = 'https://${keyVault.name}${environment().suffixes.keyvaultDns}/'
output appInsightsConnectionString string = appInsights.properties.ConnectionString
