# Marketing Mix Modelling: FourTex
# Strategic Marketing Decision Making, Erasmus University Rotterdam (Group 22)
#
# How much do Google Ads, Facebook and TikTok drive weekly sales,
# which channel gives the best return, and how should the budget be split?
#
# Run from the repository root:  Rscript R/marketing_mix_model.R
# Expects the course dataset at data/marketing_mix.csv (not included, see data/README.md)

library(ggplot2)
options(scipen = 999)
dir.create("figures", showWarnings = FALSE)

# ---- Data ----
data <- read.csv("data/marketing_mix.csv")

google.ads <- ts(data$Google.Ads, frequency = 52, start = c(2018, 1))
facebook   <- ts(data$Facebook,   frequency = 52, start = c(2018, 1))
tiktok     <- ts(data$TikTok,     frequency = 52, start = c(2018, 1))
sales      <- ts(data$Sales,      frequency = 52, start = c(2018, 1))

# ---- A first look at the data ----
png("figures/01_sales_and_spend.png", width = 1400, height = 900, res = 150)
par(mfrow = c(2, 2))
plot(sales,      col = "purple", main = "Weekly sales")
plot(tiktok,     col = "pink",   main = "TikTok spending")
plot(facebook,   col = "blue",   main = "Facebook spending")
plot(google.ads, col = "red",    main = "Google Ads spending")
dev.off()

# ---- Question 1: marketing mix model ----
# Baseline models (kept for comparison): linear, then linear with a sales lag
regression1 <- lm(sales ~ google.ads + facebook + tiktok)
summary(regression1)

m <- 1
n <- length(sales)
L1.sales <- c(rep(NA, m), sales[1:(n - m)])
regression2 <- lm(sales ~ L1.sales + google.ads + facebook + tiktok)
summary(regression2)

# Final model: log-log with a lagged dependent variable
# (captures diminishing returns and carry-over; +1 avoids log(0))
lngoogle.ads <- log(google.ads + 1)
lnfacebook   <- log(facebook + 1)
lntiktok     <- log(tiktok + 1)
lnsales      <- log(sales + 1)
L1.lnsales   <- c(rep(NA, m), lnsales[1:(n - m)])

regression3 <- lm(lnsales ~ L1.lnsales + lngoogle.ads + lnfacebook + lntiktok)
summary(regression3)

fitted_sales <- ts(regression3$fitted.values, frequency = 52, start = c(2018, 1))
png("figures/02_model_fit.png", width = 1400, height = 800, res = 150)
plot(lnsales, type = "l", col = "blue", main = "Logged sales: data vs. model", lwd = 2)
lines(fitted_sales, type = "b", col = "red")
legend("topleft", lty = 1, col = c("blue", "red"), c("Logged sales data", "Fitted"))
dev.off()

# Elasticities -> unit effects -> contribution to sales
beta_adwords  <- summary(regression3)$coefficients[3, 1]
beta_facebook <- summary(regression3)$coefficients[4, 1]
beta_tiktok   <- summary(regression3)$coefficients[5, 1]

average_sales <- mean(sales)
theta_adwords  <- beta_adwords  * (average_sales / mean(google.ads))
theta_facebook <- beta_facebook * (average_sales / mean(facebook))
theta_tiktok   <- beta_tiktok   * (average_sales / mean(tiktok))

cost_adwords  <- sum(google.ads)
cost_facebook <- sum(facebook)
cost_tiktok   <- sum(tiktok)
cost_total    <- cost_adwords + cost_facebook + cost_tiktok

adwords_contribution  <- theta_adwords  * cost_adwords
facebook_contribution <- theta_facebook * cost_facebook
tiktok_contribution   <- theta_tiktok   * cost_tiktok
media_contribution <- round(c(adwords_contribution, facebook_contribution, tiktok_contribution))

# ---- Question 2: return on marketing investment ----
roi <- round(c(adwords_contribution / cost_adwords,
               facebook_contribution / cost_facebook,
               tiktok_contribution / cost_tiktok), 3)
df_roi <- data.frame(media_names = c("Google Ads", "Facebook", "TikTok"), roi = roi)
print(df_roi)

p_roi <- ggplot(df_roi, aes(x = media_names, y = roi, fill = media_names)) +
  geom_bar(stat = "identity", color = "black") +
  scale_fill_manual(values = c("Google Ads" = "#d9534f", "Facebook" = "#f0ad4e", "TikTok" = "#337ab7")) +
  geom_text(aes(label = roi), vjust = -0.4, size = 4) +
  labs(title = "Sales return on marketing investment", x = NULL, y = "ROI") +
  theme_minimal() + theme(legend.position = "none")
ggsave("figures/03_roi_by_channel.png", p_roi, width = 7, height = 4.5, dpi = 150)

df_cost <- data.frame(type = rep(c("Sales contribution", "Cost"), each = 3),
                      media_names = rep(c("Google Ads", "Facebook", "TikTok"), 2),
                      values = c(media_contribution, round(c(cost_adwords, cost_facebook, cost_tiktok))))
p_cost <- ggplot(df_cost, aes(x = media_names, y = values, fill = type)) +
  geom_bar(stat = "identity", color = "black", position = position_dodge()) +
  labs(title = "Sales contribution vs. media cost", x = NULL, y = NULL, fill = NULL) +
  theme_minimal()
ggsave("figures/04_contribution_vs_cost.png", p_cost, width = 7, height = 4.5, dpi = 150)

# ---- Question 3: budget allocation ----
actual  <- c(cost_adwords, cost_facebook, cost_tiktok) / cost_total
beta_all <- beta_adwords + beta_facebook + beta_tiktok
optimal <- c(beta_adwords, beta_facebook, beta_tiktok) / beta_all

lbl <- function(names, shares) paste0(names, " ", round(shares * 100), "%")
png("figures/05_budget_actual_vs_optimal.png", width = 1600, height = 800, res = 150)
par(mfrow = c(1, 2))
cols <- c("#d9534f", "#f0ad4e", "#337ab7")
pie(actual,  labels = lbl(c("Google Ads", "Facebook", "TikTok"), actual),  col = cols, main = "Actual ad spending")
pie(optimal, labels = lbl(c("Google Ads", "Facebook", "TikTok"), optimal), col = cols, main = "Optimal budget allocation")
dev.off()

print(data.frame(channel = c("Google Ads", "Facebook", "TikTok"),
                 actual_share = round(actual, 2), optimal_share = round(optimal, 2)))

# ---- Question 4: do channels reinforce or cannibalise each other? ----
regression4 <- lm(lnsales ~ L1.lnsales + lngoogle.ads + lnfacebook + lntiktok
                  + lntiktok:lnfacebook + lntiktok:lngoogle.ads + lnfacebook:lngoogle.ads)
summary(regression4)
