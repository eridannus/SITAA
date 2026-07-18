# Sistema de diseño de SITAA

Este documento es la fuente de verdad visual y de interacción para las interfaces actuales y futuras de SITAA. Los componentes pueden usar Tailwind para estructura y espaciado, pero color, estados y controles deben usar los tokens y contratos semánticos definidos aquí.

## Principios

- Institucional y contemporáneo, inspirado en la identidad azul y oro de la UNAM sin reproducir literalmente otro sistema.
- Lectura cómoda para alumnado y personal docente de distintas edades.
- Accesibilidad antes que decoración; comportamiento predecible antes que novedad visual.
- Color restringido y semántico, nunca paletas arbitrarias por pantalla.
- Acciones y estados se distinguen también mediante texto, iconos o estructura.

## Tokens de marca

| Token | Valor | Uso |
| --- | --- | --- |
| `--sitaa-blue` | `#002b5c` | Acción primaria, navegación y enlaces |
| `--sitaa-blue-dark` | `#001f43` | Hover, títulos y énfasis institucional |
| `--sitaa-blue-light` | `#e8f0f8` | Hover y selección suave |
| `--sitaa-gold` | `#c9a227` | Foco, acentos y subrayados |
| `--sitaa-gold-dark` | `#7a5d00` | Eyebrows y acentos textuales breves |
| `--sitaa-page` | `#f4f7fb` | Fondo de página |
| `--sitaa-surface` | `#ffffff` | Superficies principales |
| `--sitaa-surface-subdued` | `#eef3f8` | Metadatos y superficies secundarias |
| `--sitaa-text` | `#172033` | Texto principal |
| `--sitaa-text-secondary` | `#58647a` | Ayuda y metadatos |
| `--sitaa-border` | `#cbd5e1` | Bordes neutrales |
| `--sitaa-focus` | `#c9a227` | Foco visible |

El oro se reserva para acentos, eyebrows, foco y destacados pequeños. No se usa en párrafos largos ni como fondo saturado extenso.

## Tokens semánticos

Cada estado define foreground, background y border. Verde significa exclusivamente éxito real: asistencia confirmada, operación completada o disponibilidad positiva; nunca marca, navegación o acción ordinaria.

| Estado | Foreground | Background | Border |
| --- | --- | --- | --- |
| Éxito | `--sitaa-success-foreground` | `--sitaa-success-background` | `--sitaa-success-border` |
| Advertencia | `--sitaa-warning-foreground` | `--sitaa-warning-background` | `--sitaa-warning-border` |
| Error/destructivo | `--sitaa-error-foreground` | `--sitaa-error-background` | `--sitaa-error-border` |
| Información | `--sitaa-info-foreground` | `--sitaa-info-background` | `--sitaa-info-border` |
| Neutral | `--sitaa-neutral-foreground` | `--sitaa-neutral-background` | `--sitaa-neutral-border` |
| Deshabilitado | `--sitaa-disabled-foreground` | `--sitaa-disabled-background` | `--sitaa-disabled-border` |

## Contratos de componentes

### Acciones

- **Primaria — `.sitaa-primary-action`:** fondo azul, texto blanco explícito; una acción dominante por región. Hover azul oscuro, active con desplazamiento mínimo, foco oro y altura mínima de 48 px.
- **Secundaria — `.sitaa-secondary-action`:** superficie blanca, borde y texto azul; alternativas ordinarias.
- **Terciaria — `.sitaa-tertiary-action`:** sin borde dominante; navegación contextual o acciones de menor peso.
- **Destructiva — `.sitaa-destructive-action`:** tokens de error, confirmación cuando corresponda; nunca para cancelar o volver.
- **Icono — `.sitaa-icon-action`:** objetivo mínimo 44×44, nombre accesible obligatorio. No se usa un icono sin `aria-label` cuando no hay texto visible.
- Todo control relleno especifica foreground y background juntos. Los deshabilitados usan tokens propios y `cursor-not-allowed`.

### Presentación semántica

- **StatusBadge / `.sitaa-status-badge`:** estado corto, no acción. Variantes neutral, info, success, warning y error; siempre incluye texto.
- **Alert / `.sitaa-alert`:** mensaje contextual con las mismas variantes. Éxito sólo tras una operación confirmada.
- **Surface/Card / `.sitaa-card`:** agrupación principal; `.sitaa-detail-card` para datos secundarios.
- **Tabs / `.sitaa-tabs` y `.sitaa-tab`:** estado seleccionado azul con texto blanco y `aria-selected`; no se representa sólo con color.
- **FormField / `.sitaa-field`:** label visible, ayuda secundaria, foco azul/oro, error con tokens de error y read-only/deshabilitado distinguible.
- **SectionHeading:** eyebrow oro oscuro, título azul oscuro y descripción secundaria; mantiene la jerarquía de la página.
- **Metric card:** `.sitaa-metric-card` y `.sitaa-metric-value`; números legibles, contexto textual obligatorio.
- **Empty state:** `.sitaa-empty-state`; explica situación y siguiente paso sin simular un error.
- **Data/detail card:** superficie neutral, wrapping seguro y metadatos secundarios consistentes.

## Mapeo de estados

| Dominio | Estado | Variante |
| --- | --- | --- |
| Actividad | Borrador | Neutral |
| Actividad | Programada | Información |
| Actividad | Completada | Neutral o éxito sólo si implica cierre satisfactorio real |
| Asistencia | Pendiente | Advertencia |
| Asistencia | Asistió | Éxito |
| Asistencia | No asistió | Error |
| Asistencia | Justificada | Información |
| Check-in | Abierto | Información |
| Check-in | Cerrado o expirado | Neutral |
| Corrección administrativa | Habilitada | Advertencia |

Una acción “Abrir” o “Reabrir” sigue siendo botón azul; el estado abierto se representa por separado como información.

## Tipografía y espaciado

- Texto base mínimo: 16 px, interlineado 1.5.
- Labels y ayudas: mínimo 14 px; metadatos compactos: 12 px sólo cuando no son contenido principal.
- Títulos: H1 30–36 px, H2 24–30 px, H3 18–20 px; jerarquía sin saltos arbitrarios.
- Ritmo recomendado: múltiplos de 4 px; separación ordinaria 8/12/16/24/32 px.
- Objetivos interactivos: mínimo 44×44; acciones primarias preferentemente 48 px.
- Texto continuo: máximo aproximado de 65–75 caracteres por línea.

## Accesibilidad y contraste

- WCAG AA para texto normal, foco visible, teclado completo, wrapping seguro, zoom al 200 % y movimiento reducido.
- Ningún estado depende sólo del color.
- Contrastes calculados con WCAG 2.x sobre los tokens vigentes:

| Combinación | Razón |
| --- | ---: |
| Blanco / azul primario | 14.00:1 |
| Azul primario / blanco | 14.00:1 |
| Texto / fondo de página | 15.14:1 |
| Texto / superficie secundaria | 14.57:1 |
| Éxito foreground/background | 8.64:1 |
| Advertencia foreground/background | 8.36:1 |
| Error foreground/background | 8.13:1 |
| Información foreground/background | 9.85:1 |
| Deshabilitado foreground/background | 6.15:1 |

## Patrones prohibidos

- Utilidades Tailwind `emerald-*` nuevas o existentes en UI.
- `green-*` para marca, navegación, botones o acciones ordinarias.
- Hexadecimales arbitrarios en TSX; la excepción documentada es dibujo calculado en canvas.
- Texto heredado dentro de controles rellenos.
- Estados elegidos independientemente por pantalla.
- Cadenas duplicadas de clases para botones, alertas, badges o tabs.
- Combinaciones de color no revisadas o texto oscuro sobre fondo oscuro.

Antes de entregar cambios visuales se ejecutan `npm run check:text`, `npm run check:ui`, `npm run lint` y `npm run build`, y se revisan 320, 375, 768, 1024 y 1440 px, además de zoom al 200 %.
