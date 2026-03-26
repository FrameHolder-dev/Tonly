package handler

import (
	"net/http"

	"github.com/FrameHolder-dev/Tonly/backend/internal/service"
)

type NFT struct {
	parser *service.Parser
}

func NewNFT() *NFT {
	return &NFT{
		parser: service.NewParser(),
	}
}

func (h *NFT) GetByAddress(w http.ResponseWriter, r *http.Request) {
	address := r.PathValue("address")
	if address == "" {
		writeError(w, http.StatusBadRequest, "address is required")
		return
	}

	nfts, err := h.parser.GetNFTs(r.Context(), address)
	if err != nil {
		writeError(w, http.StatusBadGateway, "failed to fetch nfts")
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"nfts": nfts,
	})
}
