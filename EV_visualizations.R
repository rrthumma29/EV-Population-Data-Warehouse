# ============================================================
#  EV Population Data Warehouse — R Visualizations
#  MGMT 6570 Advanced Data Resource Management
#  Rensselaer Polytechnic Institute | May 2026
#
#  Generates 6 figures from analysis query CSVs exported
#  from SQL Server Management Studio.
#
#  Required packages: ggplot2, dplyr, scales, tidyr
#  Install with: install.packages(c("ggplot2","dplyr","scales","tidyr"))
#
# ============================================================

library(ggplot2)
library(dplyr)
library(scales)
library(tidyr)

# ── Shared theme ──────────────────────────────────────────────────────────────
ev_theme <- theme_minimal(base_size = 12) +
  theme(
    plot.title    = element_text(face = "bold", size = 13, hjust = 0.5, margin = margin(b = 10)),
    plot.subtitle = element_text(size = 10, hjust = 0.5, color = "grey40"),
    axis.title    = element_text(size = 11),
    axis.text     = element_text(size = 10),
    legend.title  = element_text(size = 10, face = "bold"),
    legend.text   = element_text(size = 10),
    panel.grid.major.x = element_line(color = "grey90"),
    panel.grid.minor   = element_blank(),
    plot.margin   = margin(15, 15, 15, 15)
  )

EV_BLUE   <- "#2E5FA3"
EV_ORANGE <- "#E8A838"
EV_GREEN  <- "#3A9E6F"
EV_RED    <- "#C94040"

# =============================================================
#  FIGURE 1 — Registrations and Avg Electric Range by Make
# =============================================================

make_df <- read.csv("registrations_by_make.csv", header = FALSE,
                    col.names = c("Make","Registrations","AvgRange","MaxRange"))

# Top 10 only
top10 <- make_df %>% arrange(desc(Registrations)) %>% slice(1:10)
top10$Make <- factor(top10$Make, levels = rev(top10$Make))

# Scale factor to align secondary axis
scale_factor <- max(top10$Registrations) / max(top10$AvgRange)

fig1 <- ggplot(top10, aes(x = Make)) +
  geom_col(aes(y = Registrations), fill = EV_BLUE, alpha = 0.85, width = 0.6) +
  geom_line(aes(y = AvgRange * scale_factor, group = 1),
            color = EV_ORANGE, linewidth = 1.2) +
  geom_point(aes(y = AvgRange * scale_factor),
             color = EV_ORANGE, size = 3) +
  scale_y_continuous(
    labels = comma,
    sec.axis = sec_axis(~ . / scale_factor,
                        name = "Avg Electric Range (miles)",
                        labels = comma)
  ) +
  scale_x_discrete() +
  coord_flip() +
  labs(
    title    = "Figure 1 — EV Registrations and Average Electric Range by Make (Top 10)",
    x        = NULL,
    y        = "Registrations"
  ) +
  ev_theme +
  theme(axis.title.y.right = element_text(color = EV_ORANGE),
        axis.text.y.right  = element_text(color = EV_ORANGE))

ggsave("fig1_registrations_by_make.png", fig1, width = 10, height = 5, dpi = 150)
cat("Figure 1 saved\n")


# =============================================================
#  FIGURE 2 — BEV vs PHEV Registrations by Model Year
# =============================================================

year_df <- read.csv("bev_phev_by_year.csv", header = FALSE,
                    col.names = c("ModelYear","EVEra","EVType","Registrations","AvgRange"))

year_df$ModelYear <- as.integer(year_df$ModelYear)

# Era boundary lines for annotation
era_breaks <- c(2010.5, 2015.5, 2019.5)
era_labels <- data.frame(
  x     = c(2005, 2013, 2017.5, 2021.5),
  label = c("Early\nAdoption", "Growth\nPhase", "Mainstream\nEntry", "Mass\nMarket")
)

fig2 <- ggplot(year_df, aes(x = ModelYear, y = Registrations, fill = EVType)) +
  geom_col(position = "dodge", alpha = 0.85, width = 0.7) +
  geom_vline(xintercept = era_breaks, linetype = "dashed",
             color = "grey60", linewidth = 0.7) +
  scale_fill_manual(values = c("BEV" = EV_BLUE, "PHEV" = EV_ORANGE),
                    name = "Vehicle Type") +
  scale_x_continuous(breaks = seq(2000, 2023, 2)) +
  scale_y_continuous(labels = comma) +
  labs(
    title = "Figure 2 — BEV vs PHEV Registrations by Model Year",
    x     = "Model Year",
    y     = "Registrations"
  ) +
  ev_theme +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("fig2_bev_phev_by_year.png", fig2, width = 12, height = 5, dpi = 150)
cat("Figure 2 saved\n")


# =============================================================
#  FIGURE 3 — Top 15 Counties by EV Registration Count
# =============================================================

county_df <- read.csv("top_counties.csv", header = FALSE,
                      col.names = c("County","State","Registrations",
                                    "AvgRange","BEVCount","PHEVCount"))

county_df <- county_df %>% arrange(desc(Registrations))
county_df$County <- factor(county_df$County, levels = rev(county_df$County))

county_long <- county_df %>%
  select(County, BEVCount, PHEVCount) %>%
  pivot_longer(cols = c(BEVCount, PHEVCount),
               names_to  = "EVType",
               values_to = "Count") %>%
  mutate(EVType = recode(EVType, "BEVCount" = "BEV", "PHEVCount" = "PHEV"))

fig3 <- ggplot(county_long, aes(x = County, y = Count, fill = EVType)) +
  geom_col(alpha = 0.85) +
  scale_fill_manual(values = c("BEV" = EV_BLUE, "PHEV" = EV_ORANGE),
                    name = "Vehicle Type") +
  scale_y_continuous(labels = comma) +
  coord_flip() +
  labs(
    title = "Figure 3 — Top 15 Counties by EV Registration Count (BEV vs PHEV)",
    x     = NULL,
    y     = "Registrations"
  ) +
  ev_theme

ggsave("fig3_top_counties.png", fig3, width = 10, height = 6, dpi = 150)
cat("Figure 3 saved\n")


# =============================================================
#  FIGURE 4 — CAFV Eligibility Breakdown by EV Type
# =============================================================

cafv_df <- read.csv("cafv_eligibility.csv", header = FALSE,
                    col.names = c("EVType","CAFVLabel","IsEligible",
                                  "Registrations","AvgRange"))

cafv_df$Label <- paste0(cafv_df$EVType, " — ", cafv_df$CAFVLabel)
cafv_df$Label <- factor(cafv_df$Label, levels = rev(cafv_df$Label))

cafv_colors <- c(
  "BEV — Eligible"     = EV_BLUE,
  "BEV — Unknown"      = "#7BA7D6",
  "BEV — Not Eligible" = "#C8D8ED",
  "PHEV — Not Eligible"= EV_RED,
  "PHEV — Eligible"    = EV_ORANGE
)

fig4 <- ggplot(cafv_df, aes(x = Label, y = Registrations, fill = Label)) +
  geom_col(alpha = 0.88, width = 0.6) +
  geom_text(aes(label = comma(Registrations)),
            hjust = -0.1, size = 3.5) +
  scale_fill_manual(values = cafv_colors, guide = "none") +
  scale_y_continuous(labels = comma,
                     limits = c(0, max(cafv_df$Registrations) * 1.15)) +
  coord_flip() +
  labs(
    title = "Figure 4 — CAFV Eligibility Breakdown by EV Type",
    x     = NULL,
    y     = "Registrations"
  ) +
  ev_theme

ggsave("fig4_cafv_eligibility.png", fig4, width = 9, height = 5, dpi = 150)
cat("Figure 4 saved\n")


# =============================================================
#  FIGURE 5 — Top 10 Electric Utilities by Registration Count
# =============================================================

util_df <- read.csv("top_utilities.csv", header = FALSE,
                    col.names = c("Utility","Registrations","AvgRange",
                                  "BEVCount","PHEVCount"))

# Shorten long utility names for readability
util_df$UtilityShort <- c(
  "Puget Sound Energy",
  "Bonneville Power Admin",
  "City of Seattle (WA)",
  "PacifiCorp",
  "Modern Electric Water",
  "PUD No 1 Chelan Cty",
  "Unknown",
  "PUD No 2 Grant Cty",
  "Avista Corp",
  "PUD No 1 Douglas Cty"
)

util_df$UtilityShort <- factor(util_df$UtilityShort,
                                levels = rev(util_df$UtilityShort))

util_long <- util_df %>%
  select(UtilityShort, BEVCount, PHEVCount) %>%
  pivot_longer(cols = c(BEVCount, PHEVCount),
               names_to  = "EVType",
               values_to = "Count") %>%
  mutate(EVType = recode(EVType, "BEVCount" = "BEV", "PHEVCount" = "PHEV"))

fig5 <- ggplot(util_long, aes(x = UtilityShort, y = Count, fill = EVType)) +
  geom_col(position = "dodge", alpha = 0.85, width = 0.65) +
  scale_fill_manual(values = c("BEV" = EV_BLUE, "PHEV" = EV_ORANGE),
                    name = "Vehicle Type") +
  scale_y_continuous(labels = comma) +
  coord_flip() +
  labs(
    title = "Figure 5 — Top 10 Electric Utilities by EV Registration Count",
    x     = NULL,
    y     = "Registrations"
  ) +
  ev_theme

ggsave("fig5_top_utilities.png", fig5, width = 10, height = 5, dpi = 150)
cat("Figure 5 saved\n")


# =============================================================
#  FIGURE 6 — EV Adoption by Era
# =============================================================

era_df <- read.csv("adoption_by_era.csv", header = FALSE,
                   col.names = c("EVEra","Decade","Registrations",
                                 "AvgRange","BEVCount","PHEVCount"))

# Collapse 2 Early Adoption rows (2000s and 2010s decade split)
era_df <- era_df %>%
  group_by(EVEra) %>%
  summarise(
    Registrations = sum(Registrations),
    AvgRange      = round(mean(AvgRange)),
    BEVCount      = sum(BEVCount),
    PHEVCount     = sum(PHEVCount)
  ) %>%
  ungroup()

era_order <- c(
  "Early Adoption (2000-2010)",
  "Growth Phase (2011-2015)",
  "Mainstream Entry (2016-2019)",
  "Mass Market (2020-2023)"
)
era_df$EVEra <- factor(era_df$EVEra, levels = era_order)

era_long <- era_df %>%
  select(EVEra, BEVCount, PHEVCount) %>%
  pivot_longer(cols = c(BEVCount, PHEVCount),
               names_to  = "EVType",
               values_to = "Count") %>%
  mutate(EVType = recode(EVType, "BEVCount" = "BEV", "PHEVCount" = "PHEV"))

# Scale factor for secondary axis
scale_f <- max(era_df$Registrations) / max(era_df$AvgRange)

fig6 <- ggplot() +
  geom_col(data = era_long,
           aes(x = EVEra, y = Count, fill = EVType),
           position = "dodge", alpha = 0.85, width = 0.6) +
  geom_line(data = era_df,
            aes(x = EVEra, y = AvgRange * scale_f, group = 1),
            color = EV_GREEN, linewidth = 1.3) +
  geom_point(data = era_df,
             aes(x = EVEra, y = AvgRange * scale_f),
             color = EV_GREEN, size = 4) +
  scale_fill_manual(values = c("BEV" = EV_BLUE, "PHEV" = EV_ORANGE),
                    name = "Vehicle Type") +
  scale_y_continuous(
    labels   = comma,
    sec.axis = sec_axis(~ . / scale_f,
                        name   = "Avg Electric Range (miles)",
                        labels = comma)
  ) +
  scale_x_discrete(labels = function(x) gsub(" \\(", "\n(", x)) +
  labs(
    title = "Figure 6 — EV Adoption by Era: Registration Count and Average Electric Range",
    x     = NULL,
    y     = "Registrations"
  ) +
  ev_theme +
  theme(axis.title.y.right = element_text(color = EV_GREEN),
        axis.text.y.right  = element_text(color = EV_GREEN))

ggsave("fig6_adoption_by_era.png", fig6, width = 10, height = 5, dpi = 150)
cat("Figure 6 saved\n")


