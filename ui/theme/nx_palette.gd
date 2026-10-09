class_name NxPalette
extends RefCounted
## Design tokens of the NEXUS visual identity.
##
## Every colour, spacing, radius and font size used by the interface comes
## from here. The theme builder (nx_theme_builder.gd) turns these tokens into
## the project Theme, and scripts that draw custom UI read them directly.

# --- Surfaces (graphite with a faint blue tint) ------------------------------
const BG_0 := Color("0b0d10")        ## Application background, viewport clear.
const BG_1 := Color("12151a")        ## Panels, bars.
const BG_2 := Color("181c22")        ## Cards, raised blocks.
const BG_3 := Color("1f242c")        ## Inputs, secondary buttons.
const BG_4 := Color("29303a")        ## Hover / pressed surfaces.
const OVERLAY := Color(0.02, 0.025, 0.03, 0.72)  ## Modal backdrop.

# --- Lines ----------------------------------------------------------------
const BORDER := Color("262c35")
const BORDER_STRONG := Color("394150")

# --- Text -----------------------------------------------------------------
const TEXT := Color("e6eaf0")
const TEXT_MUTED := Color("9aa3b2")
const TEXT_DIM := Color("5f6876")
const TEXT_ON_ACCENT := Color("051518")

# --- Accent: electric cyan ------------------------------------------------
const ACCENT := Color("2bd4e8")
const ACCENT_HOVER := Color("62e4f3")
const ACCENT_PRESSED := Color("17adbf")
const ACCENT_SOFT := Color(0.169, 0.831, 0.91, 0.14)   ## Selected rows, toggled tools.
const ACCENT_GLOW := Color(0.169, 0.831, 0.91, 0.35)

# --- Feedback -------------------------------------------------------------
const SUCCESS := Color("3ddc97")
const WARNING := Color("f2b84b")
const DANGER := Color("f2545b")
const DANGER_HOVER := Color("ff7076")

# --- Domains (component categories) ---------------------------------------
const MECHANICAL := Color("e8a35a")
const ENERGY := Color("f0d35b")
const FLUID := Color("4ea8f5")
const LOGIC := Color("b58cf5")

# --- Spacing scale (pixels, before UI scaling) ----------------------------
const SPACE_XS := 4
const SPACE_S := 8
const SPACE_M := 12
const SPACE_L := 16
const SPACE_XL := 24
const SPACE_XXL := 32

# --- Corner radii ---------------------------------------------------------
const RADIUS_S := 4
const RADIUS_M := 6
const RADIUS_L := 10

# --- Type scale -----------------------------------------------------------
const FONT_CAPTION := 12
const FONT_BODY := 15
const FONT_LABEL := 14
const FONT_TITLE := 18
const FONT_HEADLINE := 26
const FONT_MENU := 20
const FONT_DISPLAY := 88

# --- Motion (seconds) -----------------------------------------------------
const ANIM_FAST := 0.12
const ANIM_NORMAL := 0.2
const ANIM_SLOW := 0.35


## Returns the accent colour associated with a component domain id.
static func domain_color(domain: StringName) -> Color:
	match domain:
		&"mechanical":
			return MECHANICAL
		&"energy":
			return ENERGY
		&"fluid":
			return FLUID
		&"logic":
			return LOGIC
	return ACCENT


## Returns a colour for a feedback kind: info, success, warning, error.
static func feedback_color(kind: StringName) -> Color:
	match kind:
		&"success":
			return SUCCESS
		&"warning":
			return WARNING
		&"error":
			return DANGER
	return ACCENT
