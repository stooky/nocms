# NOCMS

A no-CMS website builder for SMBs. Generate professional websites for HVAC, Plumbing, and other service businesses in minutes.

Built with **Astro 5**, **Tailwind CSS 4**, and **TypeScript**.

---

## Quick Start

```bash
# Clone
git clone https://github.com/stooky/nocms.git my-client-site
cd my-client-site

# Install
npm install

# Launch with a vertical
npm run launch hvac

# Start dev server
npm run dev
```

Then edit `src/config/vertical.ts` with your client's information.

---

## Available Verticals

| Vertical | Command | Description |
|----------|---------|-------------|
| HVAC | `npm run launch hvac` | Heating, cooling, air quality |
| Plumbing | `npm run launch plumbing` | Drains, water heaters, fixtures |

More verticals coming soon: Electrical, Roofing, Dental, Legal, etc.

---

## Features

Each vertical includes configurable features:

| Feature | HVAC | Plumbing | Description |
|---------|:----:|:--------:|-------------|
| Emergency Banner | ✓ | ✓ | Sticky 24/7 emergency CTA |
| Service Areas | ✓ | ✓ | Coverage map + city pages |
| Maintenance Plans | ✓ | - | Recurring service plans |
| Financing | ✓ | ✓ | Payment options display |
| Before/After Gallery | ✓ | ✓ | Project photo gallery |
| Reviews | ✓ | ✓ | Customer testimonials |
| Blog | ✓ | ✓ | Content marketing |
| Coupons | - | ✓ | Special offers page |
| Seasonal Messaging | ✓ | - | Auto-adjust by season |

Toggle any feature on/off in the config.

---

## Commands

| Command | Description |
|---------|-------------|
| `npm run dev` | Start dev server (localhost:4321) |
| `npm run build` | Build for production |
| `npm run preview` | Preview production build |
| `npm run launch <vertical>` | Initialize a vertical |
| `npm run validate` | Check config for issues |

---

## Project Structure

```
nocms/
├── docs/                    # Documentation
│   ├── SETUP.md            # Full setup guide
│   ├── WORKFLOW.md         # Git workflow guide
│   ├── VERTICALS.md        # All verticals overview
│   └── GAMEPLAN-*.md       # Vertical-specific plans
├── scripts/
│   ├── launch.js           # Vertical launcher
│   └── validate.js         # Config validator
├── src/
│   ├── components/         # Reusable UI components
│   ├── config/
│   │   ├── site.ts         # Base site config
│   │   └── vertical.ts     # Active vertical config (generated)
│   ├── content/
│   │   └── blog/           # Blog posts (markdown)
│   ├── layouts/
│   │   └── Layout.astro    # Main layout
│   ├── pages/              # Route pages
│   ├── styles/
│   │   └── global.css      # Global styles
│   └── verticals/          # Vertical configurations
│       └── home-services/
│           └── config/
│               ├── hvac.ts
│               ├── plumbing.ts
│               └── types.ts
└── public/                  # Static assets
```

---

## Configuration

After running `npm run launch <vertical>`, edit `src/config/vertical.ts`:

### Business Info (Required)

```typescript
business: {
  name: 'Your Business Name',
  phone: '(555) 123-4567',
  email: 'info@yourbusiness.com',
  address: {
    street: '123 Main St',
    city: 'Your City',
    state: 'ST',
    zip: '12345',
  },
  license: 'License #12345',
  yearEstablished: 2010,
},
```

### Toggle Features

```typescript
features: {
  emergency: { enabled: true },
  serviceArea: { enabled: true },
  maintenancePlans: { enabled: true },
  financing: { enabled: false },  // Disable if no financing partner
  gallery: { enabled: true },
  reviews: { enabled: true },
  blog: { enabled: true },
  // ...
},
```

---

## Workflow for Client Sites

### Option 1: Branch per client

```bash
git checkout main
git checkout -b sites/client-name
npm run launch hvac
# customize, commit, deploy
```

### Option 2: Clone for each client

```bash
git clone https://github.com/stooky/nocms.git client-name
cd client-name
npm run launch hvac
# customize, deploy
```

See `docs/WORKFLOW.md` for complete guide.

---

## Deployment

### Vercel
```bash
npm i -g vercel
vercel
```

### Netlify
```bash
npm i -g netlify-cli
netlify deploy --prod
```

### Static Host
```bash
npm run build
# Upload dist/ folder
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [SETUP.md](docs/SETUP.md) | Complete setup guide |
| [WORKFLOW.md](docs/WORKFLOW.md) | Git workflow and branching |
| [VERTICALS.md](docs/VERTICALS.md) | All verticals overview |
| [GAMEPLAN-HVAC-PLUMBING.md](docs/GAMEPLAN-HVAC-PLUMBING.md) | HVAC/Plumbing details |

---

## Tech Stack

- **[Astro](https://astro.build)** - Static site framework
- **[Tailwind CSS](https://tailwindcss.com)** - Utility-first CSS
- **[TypeScript](https://typescriptlang.org)** - Type safety

---

## License

MIT
