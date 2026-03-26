package config

import "os"

type Config struct {
	Port        string
	TONAPIBase  string
	TonAPIV3    string
	TonAPIKey   string
	Env         string
	WSPort      string
	DNSResolver string
}

func Load() *Config {
	return &Config{
		Port:        getEnv("PORT", "8080"),
		TONAPIBase:  getEnv("TON_API_BASE", "https://toncenter.com/api/v2"),
		TonAPIV3:    getEnv("TONAPI_V3", "https://tonapi.io/v2"),
		TonAPIKey:   getEnv("TONAPI_KEY", ""),
		Env:         getEnv("ENV", "development"),
		WSPort:      getEnv("WS_PORT", "3200"),
		DNSResolver: getEnv("DNS_RESOLVER", "https://tonapi.io/v2"),
	}
}

func getEnv(key, fallback string) string {
	if val, ok := os.LookupEnv(key); ok {
		return val
	}
	return fallback
}
