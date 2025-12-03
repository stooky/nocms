# NOCMS Workflow Guide

This document explains how to use the NOCMS system to create and manage SMB websites.

---

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/stooky/nocms.git my-client-site
cd my-client-site

# 2. Install dependencies
npm install

# 3. Launch with a vertical
npm run launch hvac

# 4. Edit configuration
# Open src/config/vertical.ts and update business info

# 5. Start development
npm run dev

# 6. Validate before deploy
npm run validate

# 7. Build for production
npm run build
```

---

## Repository Structure

```
nocms/
├── main branch           # Stable boilerplate (don't modify directly)
├── develop branch        # Integration branch for new features
├── feature/* branches    # Individual feature development
└── sites/* branches      # Client site branches (forked from main)
```

---

## Branch Strategy

### For Framework Development

```
main ──────────────────────────────────────────────────►
  │
  └── develop ─────────────────────────────────────────►
        │
        ├── feature/hvac-components ──► merge to develop
        ├── feature/plumbing-components ──► merge to develop
        └── feature/new-vertical ──► merge to develop
```

**Rules:**
- `main` = always stable, deployable boilerplate
- `develop` = integration testing before main
- `feature/*` = isolated feature development
- Merge to `develop` first, then `develop` to `main`

### For Client Sites

```
main ──────────────────────────────────────────────────►
  │
  ├── sites/acme-hvac ─────────────────────────────────►
  ├── sites/bobs-plumbing ─────────────────────────────►
  └── sites/cool-air-co ───────────────────────────────►
```

**Rules:**
- Branch from `main` for each new client
- Client branches are independent (don't merge back)
- Can cherry-pick bug fixes from `main` if needed

---

## Creating a New Client Site

### Option 1: Branch Method (Recommended)

Best for: Sites you'll maintain long-term, multiple sites from one repo.

```bash
# Start from main
git checkout main
git pull origin main

# Create client branch
git checkout -b sites/client-name

# Initialize vertical
npm run launch hvac

# Customize
# Edit src/config/vertical.ts
# Add images, content, etc.

# Commit and push
git add .
git commit -m "Initial setup for Client Name"
git push -u origin sites/client-name
```

### Option 2: Fork Method

Best for: Handing off to client, separate repository needed.

```bash
# Clone fresh copy
git clone https://github.com/stooky/nocms.git client-name
cd client-name

# Remove origin (optional - if creating new repo)
git remote remove origin

# Initialize vertical
npm run launch hvac

# Set up new remote (if needed)
git remote add origin https://github.com/client/their-site.git
git push -u origin main
```

---

## Available Commands

| Command | Description |
|---------|-------------|
| `npm run dev` | Start development server (localhost:4321) |
| `npm run build` | Build for production |
| `npm run preview` | Preview production build |
| `npm run launch <vertical>` | Initialize a vertical |
| `npm run validate` | Check configuration for issues |

### Launch Options

```bash
npm run launch hvac              # Initialize HVAC vertical
npm run launch plumbing          # Initialize Plumbing vertical
npm run launch hvac --force      # Reinitialize (overwrites config)
```

---

## Configuration Workflow

### 1. Launch Vertical

```bash
npm run launch hvac
```

This creates:
- `src/config/vertical.ts` - Your main configuration file
- `.vertical` - Marker file tracking which vertical is active

### 2. Update Business Information

Edit `src/config/vertical.ts`:

```typescript
business: {
  name: 'Your Business Name',        // ← Update
  phone: '(555) 123-4567',           // ← Update
  email: 'info@yourbusiness.com',    // ← Update
  address: {
    street: '123 Main Street',       // ← Update
    city: 'Your City',               // ← Update
    state: 'ST',                     // ← Update
    zip: '12345',                    // ← Update
  },
  license: 'License #12345',         // ← Update
  yearEstablished: 2010,             // ← Update
},
```

### 3. Enable/Disable Features

```typescript
features: {
  emergency: { enabled: true },           // 24/7 banner
  serviceArea: { enabled: true },         // Service area pages
  maintenancePlans: { enabled: true },    // Maintenance plans (HVAC)
  financing: { enabled: true },           // Financing options
  gallery: { enabled: true },             // Before/after gallery
  reviews: { enabled: true },             // Customer reviews
  blog: { enabled: true },                // Blog section
  coupons: { enabled: false },            // Coupons page
  scheduling: { enabled: false },         // Online scheduling
  liveChat: { enabled: false },           // Chat widget
  seasonalMessaging: { enabled: true },   // Seasonal headlines
},
```

### 4. Configure Each Feature

Each enabled feature has its own configuration section. For example:

```typescript
// Emergency banner config
emergency: {
  headline: "No Heat? No AC? We're On Our Way!",
  subheadline: '24/7 Emergency HVAC Service',
  responseTime: '60 minutes or less',
  phone: '(555) 123-4567',
  variant: 'sticky',
  colorScheme: 'urgent',
},

// Service area config
serviceArea: {
  radiusMiles: 30,
  cities: ['Springfield', 'Decatur', 'Champaign'],
  generateCityPages: true,
},
```

### 5. Add Content

**Images:**
```
public/
├── images/
│   ├── logo.png              # Your logo
│   ├── gallery/              # Project photos
│   │   ├── project-1-before.jpg
│   │   └── project-1-after.jpg
│   ├── team/                 # Team photos
│   └── brands/               # Brand logos you service
└── og-image.png              # Social sharing image (1200x630)
```

**Blog Posts:**
```
src/content/blog/
├── your-first-post.md
└── another-post.md
```

### 6. Validate

```bash
npm run validate
```

This checks:
- Required files exist
- No placeholder content remains
- Prerequisites are met

---

## Prerequisites by Feature

Some features require external accounts or assets. Check these before enabling:

### High Priority (Needed for Launch)

| Feature | Requirement |
|---------|-------------|
| Financing | Active financing partner account (Synchrony, GreenSky) |
| Reviews | Google Business Profile with 5+ reviews |
| Trust Badge: Google | Google Business Profile |

### Medium Priority (Needed Soon)

| Feature | Requirement |
|---------|-------------|
| Gallery | Minimum 3 project photos |
| Scheduling | Scheduling software (ServiceTitan, Housecall Pro) |

### Low Priority (Nice to Have)

| Feature | Requirement |
|---------|-------------|
| Live Chat | Chat service account (Intercom, Drift) |
| Trust Badge: BBB | BBB accreditation |

---

## Deployment

### Vercel (Recommended)

```bash
# Install Vercel CLI
npm i -g vercel

# Deploy
vercel

# Set up automatic deploys
vercel link
```

### Netlify

```bash
# Install Netlify CLI
npm i -g netlify-cli

# Deploy
netlify deploy --prod
```

### Manual

```bash
# Build
npm run build

# Upload dist/ folder to your host
```

---

## Updating from Upstream

If you're using the branch method and want to get updates from main:

```bash
# On your client branch
git checkout sites/client-name

# Fetch latest
git fetch origin main

# Merge (or cherry-pick specific commits)
git merge origin/main

# Resolve any conflicts, test, then push
git push
```

**Warning:** Be careful merging if you've heavily customized. Consider cherry-picking specific bug fixes instead.

---

## Troubleshooting

### "Vertical already initialized"

```bash
npm run launch hvac --force
```

### Build errors after launch

1. Check `npm run validate` for issues
2. Ensure all imports are correct
3. Check for TypeScript errors: `npx tsc --noEmit`

### Styles not applying

1. Ensure Tailwind is configured: check `astro.config.mjs`
2. Clear cache: delete `node_modules/.astro`
3. Restart dev server

### Images not loading

1. Check paths are relative to `public/`
2. Paths in config should be `/images/...` (with leading slash)

---

## Getting Help

- Documentation: `docs/` folder
- Issues: https://github.com/stooky/nocms/issues
- Verticals Guide: `docs/VERTICALS.md`
- HVAC/Plumbing Details: `docs/GAMEPLAN-HVAC-PLUMBING.md`
