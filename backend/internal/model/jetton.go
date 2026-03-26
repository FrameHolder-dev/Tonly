package model

type JettonBalance struct {
	Address  string  `json:"address"`
	Name     string  `json:"name"`
	Symbol   string  `json:"symbol"`
	Decimals int     `json:"decimals"`
	Balance  string  `json:"balance"`
	ImageURL string  `json:"image_url"`
	USDPrice float64 `json:"usd_price"`
	USDValue float64 `json:"usd_value"`
	Verified bool    `json:"verified"`
}

type WalletOverview struct {
	Address    string          `json:"address"`
	BalanceTON string          `json:"balance_ton"`
	BalanceUSD float64         `json:"balance_usd"`
	TONPrice   float64         `json:"ton_price"`
	Jettons    []JettonBalance `json:"jettons"`
	TotalUSD   float64         `json:"total_usd"`
}
