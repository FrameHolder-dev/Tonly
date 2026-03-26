package handler

import (
	"net/http"

	"github.com/FrameHolder-dev/Tonly/backend/internal/service"
)

type Rates struct {
	tonAPI *service.TonAPI
}

func NewRates() *Rates {
	return &Rates{
		tonAPI: service.NewTonAPI(),
	}
}

func (h *Rates) Get(w http.ResponseWriter, r *http.Request) {
	tokens := r.URL.Query().Get("tokens")
	if tokens == "" {
		tokens = "ton"
	}

	currencies := r.URL.Query().Get("currencies")
	if currencies == "" {
		currencies = "usd"
	}

	rates, err := h.tonAPI.GetRates(r.Context(), tokens, currencies)
	if err != nil {
		writeError(w, http.StatusBadGateway, "failed to fetch rates")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write(rates)
}

func (h *Rates) GetChart(w http.ResponseWriter, r *http.Request) {
	token := r.URL.Query().Get("token")
	if token == "" {
		token = "ton"
	}

	currency := r.URL.Query().Get("currency")
	if currency == "" {
		currency = "usd"
	}

	period := r.URL.Query().Get("period")
	if period == "" {
		period = "1m"
	}

	chart, err := h.tonAPI.GetChart(r.Context(), token, currency, period)
	if err != nil {
		writeError(w, http.StatusBadGateway, "failed to fetch chart")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write(chart)
}
