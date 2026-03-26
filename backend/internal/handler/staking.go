package handler

import (
	"net/http"

	"github.com/FrameHolder-dev/Tonly/backend/internal/service"
)

type Staking struct {
	tonAPI *service.TonAPI
}

func NewStaking() *Staking {
	return &Staking{
		tonAPI: service.NewTonAPI(),
	}
}

func (h *Staking) GetPools(w http.ResponseWriter, r *http.Request) {
	address := r.PathValue("address")
	if address == "" {
		writeError(w, http.StatusBadRequest, "address is required")
		return
	}

	pools, err := h.tonAPI.GetStakingPools(r.Context(), address)
	if err != nil {
		writeError(w, http.StatusBadGateway, "failed to fetch staking pools")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write(pools)
}
