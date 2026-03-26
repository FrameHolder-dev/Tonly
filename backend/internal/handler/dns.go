package handler

import (
	"net/http"

	"github.com/FrameHolder-dev/Tonly/backend/internal/service"
)

type DNS struct {
	tonAPI *service.TonAPI
}

func NewDNS() *DNS {
	return &DNS{
		tonAPI: service.NewTonAPI(),
	}
}

func (h *DNS) Resolve(w http.ResponseWriter, r *http.Request) {
	domain := r.PathValue("domain")
	if domain == "" {
		writeError(w, http.StatusBadRequest, "domain is required")
		return
	}

	result, err := h.tonAPI.ResolveDomain(r.Context(), domain)
	if err != nil {
		writeError(w, http.StatusBadGateway, "failed to resolve domain")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write(result)
}
