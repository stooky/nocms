/**
 * Home Services Vertical Components
 *
 * Specialized components for HVAC, Plumbing, and other home service websites.
 *
 * Usage in Astro:
 *   import EmergencyBanner from '@verticals/home-services/components/EmergencyBanner.astro';
 *
 * Or import the component directly:
 *   import EmergencyBanner from '../verticals/home-services/components/EmergencyBanner.astro';
 */

// Component exports are handled via direct .astro imports
// This file serves as documentation and future JS utility exports

export const components = {
  EmergencyBanner: 'EmergencyBanner.astro',
  TrustBadges: 'TrustBadges.astro',
  ServiceCallCTA: 'ServiceCallCTA.astro',
  MaintenancePlanCard: 'MaintenancePlanCard.astro',
  ReviewsCarousel: 'ReviewsCarousel.astro',
  FinancingBanner: 'FinancingBanner.astro',
  ServiceAreaMap: 'ServiceAreaMap.astro',
  BeforeAfterGallery: 'BeforeAfterGallery.astro',
} as const;

export type ComponentName = keyof typeof components;
