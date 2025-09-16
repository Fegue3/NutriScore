# 🎨 Design Tokens

## 1. Color System

### Primary Palette
| Name           | Hex     | RGB             | Usage                               |
|----------------|---------|-----------------|-------------------------------------|
| Fresh Green    | #4CAF6D | (76, 175, 109)  | Primary actions, confirmations      |
| Warm Tangerine | #FF8A4C | (255, 138, 76)  | Secondary CTAs, highlights          |
| Leafy Green    | #66BB6A | (102, 187, 106) | Success messages, progress states   |
| Golden Amber   | #FFC107 | (255, 193, 7)   | Warnings, subtle alerts             |
| Ripe Red       | #E53935 | (229, 57, 53)   | Errors, destructive actions         |

### Neutral Palette
| Name           | Hex     | RGB              | Usage                               |
|----------------|---------|------------------|-------------------------------------|
| Charcoal       | #333333 | (51, 51, 51)     | Primary text                        |
| Cool Gray      | #666666 | (102, 102, 102)  | Secondary text                      |
| Soft Off-White | #FAFAF7 | (250, 250, 247)  | App background                      |
| Light Sage     | #E8F5E9 | (232, 245, 233)  | Section / card background           |

---

## 2. Typography

### Font Families
- **Primary Headings:** Nunito Sans (Rounded, friendly)  
- **Body / General Text:** Inter (Legible, neutral)  
- **Data / Nutritional Numbers:** Roboto Mono (Precise, technical feel)  

### Font Sizes & Hierarchy
| Role                | Font        | Size | Weight   | Line Height | Usage                       |
|---------------------|-------------|------|----------|-------------|-----------------------------|
| H1 – App Title      | Nunito Sans | 32px | Bold     | 120%        | Dashboard headline          |
| H2 – Section Title  | Nunito Sans | 24px | SemiBold | 130%        | Section headers             |
| H3 – Subheadings    | Nunito Sans | 20px | Medium   | 130%        | Card headings               |
| Body                | Inter       | 16px | Regular  | 150%        | Main text, labels           |
| Small Text          | Inter       | 14px | Regular  | 150%        | Helper text                 |
| Caption / Labels    | Inter       | 12px | Medium   | 140%        | Tags, input labels          |
| Data / Metrics      | Roboto Mono | 18px | Medium   | 140%        | Calories, macros            |

---

## 3. Layout, Grid & Spacing

### Grid System
- Mobile-first design  
- **4pt base grid** → todos os espaçamentos e tamanhos são múltiplos de 4px.  

### Spacing Scale
| Size | Value | Usage                              |
|------|-------|------------------------------------|
| XS   | 4px   | Tight padding (icon + text gap)    |
| S    | 8px   | Small gaps between related UI      |
| M    | 16px  | Default padding inside cards       |
| L    | 24px  | Section padding / unrelated groups |
| XL   | 32px  | Page margins, modal spacing        |

### Container Rules
- Safe area margin: **16px** (left/right)  
- Card gutter: **8px** entre cards numa lista  
