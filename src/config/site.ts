/**
 * Member Solutions - Site Configuration
 * Membership Management Software & Billing Services
 */

export const siteConfig = {
  // Basic Info
  name: "Member Solutions",
  tagline: "Simplify Studio Management. Grow Your Membership.",
  description: "Run your studio smarter with all-in-one membership management software. Handle lead tracking, scheduling, and billing seamlessly.",
  url: "https://membersolutions.com",

  // Contact Information
  contact: {
    email: "info@membersolutions.com",
    phone: "+1 (888) 123-4567",
    address: {
      street: "123 Business Center Drive",
      city: "Philadelphia",
      state: "PA",
      zip: "19103",
      country: "USA",
    },
  },

  // Social Media Links
  social: {
    twitter: "https://twitter.com/membersolutions",
    linkedin: "https://linkedin.com/company/member-solutions",
    facebook: "https://facebook.com/membersolutions",
    instagram: "https://instagram.com/membersolutions",
    youtube: "https://youtube.com/@membersolutions",
  },

  // Business Hours
  hours: {
    monday: "8:00 AM - 6:00 PM EST",
    tuesday: "8:00 AM - 6:00 PM EST",
    wednesday: "8:00 AM - 6:00 PM EST",
    thursday: "8:00 AM - 6:00 PM EST",
    friday: "8:00 AM - 6:00 PM EST",
    saturday: "Closed",
    sunday: "Closed",
  },

  // Main Navigation with Dropdowns
  navigation: [
    {
      name: "Product",
      href: "#",
      children: [
        { name: "Full-Service Billing", href: "/membership-billing-services" },
        { name: "Member Management", href: "/member-management-software" },
        { name: "Websites & Marketing", href: "/websites-marketing-tools" },
      ],
    },
    {
      name: "Solutions",
      href: "/solutions",
      children: [
        { name: "Martial Arts", href: "/solutions/martial-arts" },
        { name: "Fitness Centers", href: "/solutions/fitness" },
      ],
    },
    {
      name: "Resources",
      href: "#",
      children: [
        { name: "About Us", href: "/about" },
        { name: "Blog", href: "/blog" },
        { name: "Privacy Policy", href: "/privacy" },
      ],
    },
    {
      name: "Support",
      href: "#",
      children: [
        { name: "Log In", href: "/login" },
        { name: "Get in Touch", href: "/contact" },
      ],
    },
    { name: "Reviews", href: "/reviews" },
  ],

  // Simple navigation for mobile/fallback
  simpleNavigation: [
    { name: "Home", href: "/" },
    { name: "Products", href: "/membership-billing-services" },
    { name: "Solutions", href: "/solutions" },
    { name: "About", href: "/about" },
    { name: "Blog", href: "/blog" },
    { name: "Reviews", href: "/reviews" },
    { name: "Contact", href: "/contact" },
  ],

  // Footer Navigation
  footerLinks: {
    product: [
      { name: "Full-Service Billing", href: "/membership-billing-services" },
      { name: "Member Management", href: "/member-management-software" },
      { name: "Websites & Marketing", href: "/websites-marketing-tools" },
    ],
    solutions: [
      { name: "Martial Arts", href: "/solutions/martial-arts" },
      { name: "Fitness Centers", href: "/solutions/fitness" },
    ],
    resources: [
      { name: "About Us", href: "/about" },
      { name: "Privacy Policy", href: "/privacy" },
      { name: "Request Information", href: "/request-info" },
      { name: "Blog", href: "/blog" },
    ],
    support: [
      { name: "Log In", href: "/login" },
      { name: "Make a Payment", href: "/payment" },
      { name: "Support Center", href: "/support" },
      { name: "Get in Touch", href: "/contact" },
    ],
  },

  // Default SEO Image
  defaultOgImage: "/og-image.png",

  // Google Analytics ID
  googleAnalyticsId: "",

  // Copyright
  copyright: `© ${new Date().getFullYear()} Member Solutions. All rights reserved.`,

  // Trust Statement
  trustStatement: "Trusted by membership businesses for 30+ years",
};

// Navigation type with optional children
export interface NavItem {
  name: string;
  href: string;
  children?: { name: string; href: string }[];
}

export type SiteConfig = typeof siteConfig;
