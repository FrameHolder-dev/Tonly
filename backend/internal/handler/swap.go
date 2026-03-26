package handler

import (
	"encoding/json"
	"io"
	"net/http"
	"time"
)

type Swap struct {
	client *http.Client
}

func NewSwap() *Swap {
	return &Swap{
		client: &http.Client{Timeout: 15 * time.Second},
	}
}

func (h *Swap) Simulate(w http.ResponseWriter, r *http.Request) {
	offerAddress := r.URL.Query().Get("offer_address")
	askAddress := r.URL.Query().Get("ask_address")
	units := r.URL.Query().Get("units")
	slippageTolerance := r.URL.Query().Get("slippage_tolerance")

	if offerAddress == "" || askAddress == "" || units == "" || slippageTolerance == "" {
		writeError(w, http.StatusBadRequest, "missing required parameters")
		return
	}

	req, err := http.NewRequestWithContext(r.Context(), http.MethodPost, "https://api.ston.fi/v1/swap/simulate", nil)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to create request")
		return
	}

	q := req.URL.Query()
	q.Set("offer_address", offerAddress)
	q.Set("ask_address", askAddress)
	q.Set("units", units)
	q.Set("slippage_tolerance", slippageTolerance)
	req.URL.RawQuery = q.Encode()

	resp, err := h.client.Do(req)
	if err != nil {
		writeError(w, http.StatusBadGateway, "failed to reach STON.fi")
		return
	}
	defer resp.Body.Close()

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(resp.StatusCode)
	io.Copy(w, resp.Body)
}

type stonRawAsset struct {
	ContractAddress string  `json:"contract_address"`
	Symbol          string  `json:"symbol"`
	DisplayName     string  `json:"display_name"`
	ImageURL        string  `json:"image_url"`
	Decimals        int     `json:"decimals"`
	Community       bool    `json:"community"`
	Blacklisted     bool    `json:"blacklisted"`
	Deprecated      bool    `json:"deprecated"`
	DefaultSymbol   bool    `json:"default_symbol"`
	USDPrice        string  `json:"third_party_usd_price"`
}

type swapAssetOut struct {
	Address  string `json:"address"`
	Symbol   string `json:"symbol"`
	Name     string `json:"name"`
	ImageURL string `json:"image_url"`
	Decimals int    `json:"decimals"`
	Verified bool   `json:"verified"`
}

func (h *Swap) GetAssets(w http.ResponseWriter, r *http.Request) {
	req, err := http.NewRequestWithContext(r.Context(), http.MethodGet, "https://api.ston.fi/v1/assets", nil)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to create request")
		return
	}

	resp, err := h.client.Do(req)
	if err != nil {
		writeError(w, http.StatusBadGateway, "failed to reach STON.fi")
		return
	}
	defer resp.Body.Close()

	var raw struct {
		AssetList []stonRawAsset `json:"asset_list"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&raw); err != nil {
		writeError(w, http.StatusBadGateway, "failed to parse STON.fi response")
		return
	}

	var result []swapAssetOut
	for _, a := range raw.AssetList {
		if a.Blacklisted || a.Deprecated {
			continue
		}
		if !a.Community && !a.DefaultSymbol {
			continue
		}
		result = append(result, swapAssetOut{
			Address:  a.ContractAddress,
			Symbol:   a.Symbol,
			Name:     a.DisplayName,
			ImageURL: a.ImageURL,
			Decimals: a.Decimals,
			Verified: a.DefaultSymbol,
		})
		if len(result) >= 50 {
			break
		}
	}

	writeJSON(w, http.StatusOK, map[string]any{"assets": result})
}
