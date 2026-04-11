package handler

import (
	"net/http"

	"github.com/FrameHolder-dev/Tonly/backend/internal/service"
)

type Jettons struct {
	parser *service.Parser
}

func NewJettons() *Jettons {
	return &Jettons{
		parser: service.NewParser(),
	}
}

func (h *Jettons) GetByAddress(w http.ResponseWriter, r *http.Request) {
	address := r.PathValue("address")
	if address == "" {
		writeError(w, http.StatusBadRequest, "address is required")
		return
	}

	currency := r.URL.Query().Get("currency")
	if currency == "" {
		currency = "usd"
	}

	jettons, err := h.parser.GetJettons(r.Context(), address, currency)
	if err != nil {
		writeError(w, http.StatusBadGateway, "failed to fetch jettons")
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"jettons": jettons,
	})
}
