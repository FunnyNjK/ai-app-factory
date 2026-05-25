# Sample Project Brief — Marketing Site with Contact Form

## Project name

Example Marketing Site

## Project type

Marketing site with serverless contact form and transactional email.

---

## Executive summary

Build a public marketing website for a small services business. The site should explain the business, present services, and allow visitors to submit a contact form. Contact form submissions should send an internal notification email through Postmark.

---

## Business goal

Generate qualified inbound leads from the website.

---

## Target users

| User type | Description | Primary needs |
|---|---|---|
| Website visitor | Prospective customer | Understand services and contact the business |
| Business owner | Site owner | Receive contact requests reliably |
| Developer/operator | Maintainer | Deploy and troubleshoot the site easily |

---

## Primary user journeys

1. Visitor lands on the home page and understands the value proposition.
2. Visitor reviews services and decides to make contact.
3. Visitor submits the contact form and receives confirmation.
4. Business owner receives an email notification.

---

## In scope for v1

- Home page
- Services section
- Contact form
- Azure Function contact endpoint
- Postmark email send
- Basic SEO metadata
- Accessibility smoke checks for keyboard navigation, labels, focus visibility, headings, and contrast
- Contact form anti-abuse decision: rate limiting plus honeypot or Turnstile
- Deployment instructions

---

## Out of scope for v1

- CMS
- Blog
- Auth
- Database persistence
- Payments
- Admin dashboard

---

## Success criteria

- Largest Contentful Paint is under 2.5 seconds on the production home page during release smoke testing.
- Contact form submissions are delivered to the business inbox.
- User receives clear success/error feedback.
- Site can be deployed through a documented process.
