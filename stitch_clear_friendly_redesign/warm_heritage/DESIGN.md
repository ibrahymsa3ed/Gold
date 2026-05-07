---
name: Warm Heritage
colors:
  surface: '#fff8f0'
  surface-dim: '#e1d9cc'
  surface-bright: '#fff8f0'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#fbf3e5'
  surface-container: '#f5eddf'
  surface-container-high: '#efe7da'
  surface-container-highest: '#eae1d4'
  on-surface: '#1f1b13'
  on-surface-variant: '#4d4635'
  inverse-surface: '#343027'
  inverse-on-surface: '#f8f0e2'
  outline: '#7f7663'
  outline-variant: '#d0c5af'
  surface-tint: '#735c00'
  primary: '#735c00'
  on-primary: '#ffffff'
  primary-container: '#d4af37'
  on-primary-container: '#554300'
  inverse-primary: '#e9c349'
  secondary: '#406562'
  on-secondary: '#ffffff'
  secondary-container: '#c0e7e4'
  on-secondary-container: '#446967'
  tertiary: '#415ba4'
  on-tertiary: '#ffffff'
  tertiary-container: '#97b0ff'
  on-tertiary-container: '#254188'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffe088'
  primary-fixed-dim: '#e9c349'
  on-primary-fixed: '#241a00'
  on-primary-fixed-variant: '#574500'
  secondary-fixed: '#c3eae7'
  secondary-fixed-dim: '#a7cecb'
  on-secondary-fixed: '#00201e'
  on-secondary-fixed-variant: '#284d4b'
  tertiary-fixed: '#dbe1ff'
  tertiary-fixed-dim: '#b4c5ff'
  on-tertiary-fixed: '#00174b'
  on-tertiary-fixed-variant: '#27438a'
  background: '#fff8f0'
  on-background: '#1f1b13'
  surface-variant: '#eae1d4'
typography:
  h1:
    fontFamily: Plus Jakarta Sans
    fontSize: 36px
    fontWeight: '700'
    lineHeight: '1.2'
  h2:
    fontFamily: Plus Jakarta Sans
    fontSize: 28px
    fontWeight: '700'
    lineHeight: '1.3'
  h3:
    fontFamily: Plus Jakarta Sans
    fontSize: 22px
    fontWeight: '600'
    lineHeight: '1.4'
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '400'
    lineHeight: '1.6'
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: '1.6'
  label-caps:
    fontFamily: Work Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: '1.0'
    letterSpacing: 0.05em
  price-display:
    fontFamily: Plus Jakarta Sans
    fontSize: 42px
    fontWeight: '700'
    lineHeight: '1.1'
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 8px
  container-margin: 24px
  gutter: 16px
  stack-sm: 8px
  stack-md: 16px
  stack-lg: 32px
  section-gap: 48px
---

## Brand & Style

The design system is anchored in the concept of "Generational Warmth." It moves away from the cold, exclusive nature of traditional bullion trading toward a helpful, family-centric tool for long-term security. The visual language is supportive and calm, prioritizing clarity over prestige.

The chosen style is **Modern Corporate with Tactile Softness**. It utilizes ample whitespace and a balanced layout to reduce cognitive load for family members of all ages. By blending a sophisticated gold with soft organic tones, the interface feels both valuable and approachable—transforming gold tracking into a shared family habit rather than a complex financial chore.

## Colors

The palette is designed to feel "sun-drenched" and inviting. The primary background (#FFFDF5) provides a soft, low-strain canvas that avoids the clinical feel of pure white or the aggression of pure black.

- **Warm Gold (#D4AF37):** Used for primary actions, brand moments, and representing gold value. It is sophisticated but matte, avoiding "glittery" gradients.
- **Deep Charcoal (#2D2D2D):** The foundation for readability. Used for all primary headlines and body copy to ensure high contrast against the cream background.
- **Soft Teal/Sage (#7BA19E / #8DAA91):** These secondary tones represent growth and stability. Use them for success states, secondary buttons, and progress indicators to balance the warmth of the gold.

## Typography

The design system utilizes **Plus Jakarta Sans** for its friendly, open apertures and modern geometric feel. It strikes a perfect balance between professional finance and a welcoming consumer app. 

**Work Sans** is introduced sparingly for labels and data points to provide a grounded, functional counterpoint. High legibility is non-negotiable; body text never drops below 16px, and line heights are intentionally generous (1.6x) to assist users with varying visual needs. Headings should always appear bold to establish a clear information hierarchy at a glance.

## Layout & Spacing

This design system uses a **Fluid Grid with Safe Margins**. The layout philosophy prioritizes "breathing room" to create a sense of calm. 

- **Grid:** A standard 12-column grid for desktop and 4-column for mobile.
- **Margins:** 24px horizontal margins on mobile to ensure content doesn't feel cramped.
- **Rhythm:** An 8px linear scale guides all vertical spacing. Elements are grouped using tight spacing (8px or 16px), while distinct sections are separated by large gaps (48px) to visually organize the user's journey without the need for heavy dividers.

## Elevation & Depth

To maintain the "friendly" aesthetic, the design system avoids harsh, realistic shadows. Depth is achieved through **Ambient Tonal Layers**.

1.  **Level 0 (Base):** The main background (#FFFDF5).
2.  **Level 1 (Cards):** Pure white (#FFFFFF) surfaces with a very soft, diffused shadow (15% opacity of the Charcoal color, 20px blur, 4px Y-offset).
3.  **Level 2 (Modals/Popovers):** Higher contrast shadows with a slight gold-tinted glow to suggest the element is "rising" toward the user.

Use soft, low-contrast outlines (1px solid #E5E1D3) on white cards to define edges on high-brightness screens without adding visual noise.

## Shapes

The shape language is consistently **Rounded**. Sharp corners are eliminated to evoke a sense of safety and friendliness. 

- **Standard Components:** Buttons and input fields use a 0.5rem (8px) radius.
- **Cards & Containers:** Use a 1rem (16px) radius to create a soft, protective feel for data.
- **Progress Bars:** Use fully rounded (pill) ends to emphasize movement and completion.
- **Icons:** Use a rounded icon set (e.g., Lucide Rounded or Feather) with a consistent 2px stroke weight to match the typography's visual weight.

## Components

- **Buttons:** Primary buttons use the Warm Gold background with White text for a "glow" effect. Secondary buttons use the Sage Green background with White text. All buttons have a minimum height of 48px for accessibility.
- **Cards:** Use white backgrounds with 16px rounded corners. Include generous internal padding (24px) to ensure gold tracking data is easy to parse.
- **Input Fields:** Use a light cream stroke (#E5E1D3) that thickens and changes to Gold on focus. Labels should always be visible above the field, never purely as placeholder text.
- **Chips:** Small, pill-shaped tags used for "Weight" or "Purity" indicators. Use Sage Green with 10% opacity for the background and full-strength Sage for the text.
- **Progress Tracking:** For savings goals, use thick, rounded progress bars in Gold with a soft Sage background for the "remaining" track.
- **Family Dashboard:** A unique component consisting of nested cards that allow users to toggle between "My Savings" and "Family Pot," using soft color transitions to indicate the active view.