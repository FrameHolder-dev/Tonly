package handler

import (
	"encoding/json"
	"net/http"

	"github.com/FrameHolder-dev/Tonly/backend/internal/service"
)

type Wallet struct {
	tonService *service.TON
	tonAPI     *service.TonAPI
	parser     *service.Parser
}

func NewWallet() *Wallet {
	return &Wallet{
		tonService: service.NewTON(),
		tonAPI:     service.NewTonAPI(),
		parser:     service.NewParser(),
	}
}

func (h *Wallet) GetBalance(w http.ResponseWriter, r *http.Request) {
	address := r.PathValue("address")
	if address == "" {
		writeError(w, http.StatusBadRequest, "address is required")
		return
	}

	balance, err := h.tonService.GetBalance(r.Context(), address)
	if err != nil {
		writeError(w, http.StatusBadGateway, "failed to fetch balance")
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"address": address,
		"balance": balance,
	})
}

func (h *Wallet) GetOverview(w http.ResponseWriter, r *http.Request) {
	address := r.PathValue("address")
	if address == "" {
		writeError(w, http.StatusBadRequest, "address is required")
		return
	}

	overview, err := h.parser.GetWalletOverview(r.Context(), address)
	if err != nil {
		writeError(w, http.StatusBadGateway, "failed to fetch overview")
		return
	}

	writeJSON(w, http.StatusOK, overview)
}

func (h *Wallet) GetAccount(w http.ResponseWriter, r *http.Request) {
	address := r.PathValue("address")
	if address == "" {
		writeError(w, http.StatusBadRequest, "address is required")
		return
	}

	account, err := h.tonAPI.GetAccount(r.Context(), address)
	if err != nil {
		writeError(w, http.StatusBadGateway, "failed to fetch account")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write(account)
}

func (h *Wallet) GetTransactions(w http.ResponseWriter, r *http.Request) {
	address := r.PathValue("address")
	if address == "" {
		writeError(w, http.StatusBadRequest, "address is required")
		return
	}

	limit := r.URL.Query().Get("limit")
	if limit == "" {
		limit = "20"
	}

	txs, err := h.tonService.GetTransactions(r.Context(), address, limit)
	if err != nil {
		writeError(w, http.StatusBadGateway, "failed to fetch transactions")
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"address":      address,
		"transactions": txs,
	})
}

func (h *Wallet) GetActivity(w http.ResponseWriter, r *http.Request) {
	address := r.PathValue("address")
	if address == "" {
		writeError(w, http.StatusBadRequest, "address is required")
		return
	}

	limit := r.URL.Query().Get("limit")
	if limit == "" {
		limit = "25"
	}

	items, err := h.parser.GetActivity(r.Context(), address, limit)
	if err != nil {
		writeError(w, http.StatusBadGateway, "failed to fetch activity")
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"address":  address,
		"activity": items,
	})
}

func (h *Wallet) GetEvents(w http.ResponseWriter, r *http.Request) {
	address := r.PathValue("address")
	if address == "" {
		writeError(w, http.StatusBadRequest, "address is required")
		return
	}

	limit := r.URL.Query().Get("limit")
	if limit == "" {
		limit = "20"
	}

	events, err := h.tonAPI.GetEvents(r.Context(), address, limit)
	if err != nil {
		writeError(w, http.StatusBadGateway, "failed to fetch events")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write(events)
}

func (h *Wallet) GetSeqno(w http.ResponseWriter, r *http.Request) {
	address := r.PathValue("address")
	if address == "" {
		writeError(w, http.StatusBadRequest, "address is required")
		return
	}

	seqno, err := h.tonAPI.GetSeqno(r.Context(), address)
	if err != nil {
		writeJSON(w, http.StatusOK, map[string]int{"seqno": 0})
		return
	}

	writeJSON(w, http.StatusOK, map[string]int{"seqno": seqno})
}

func (h *Wallet) GetTime(w http.ResponseWriter, r *http.Request) {
	t, err := h.tonAPI.GetTime(r.Context())
	if err != nil {
		writeError(w, http.StatusBadGateway, "failed to fetch time")
		return
	}
	writeJSON(w, http.StatusOK, map[string]int64{"time": t})
}

func (h *Wallet) GetJettonPayload(w http.ResponseWriter, r *http.Request) {
	address := r.PathValue("address")
	jetton := r.PathValue("jetton")
	if address == "" || jetton == "" {
		writeError(w, http.StatusBadRequest, "address and jetton are required")
		return
	}

	data, err := h.tonAPI.GetJettonCustomPayload(r.Context(), address, jetton)
	if err != nil {
		writeError(w, http.StatusBadGateway, "failed to fetch payload")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(data)
}

func (h *Wallet) EmulateTransaction(w http.ResponseWriter, r *http.Request) {
	var body struct {
		BOC string `json:"boc"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.BOC == "" {
		writeError(w, http.StatusBadRequest, "boc is required")
		return
	}

	data, err := h.tonAPI.EmulateMessage(r.Context(), body.BOC)
	if err != nil {
		writeError(w, http.StatusBadGateway, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(data)
}

func (h *Wallet) GenerateMnemonic(w http.ResponseWriter, r *http.Request) {
	result, err := service.GenerateFullWallet()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to generate wallet")
		return
	}
	writeJSON(w, http.StatusOK, result)
}

func (h *Wallet) GenerateEntropy(w http.ResponseWriter, r *http.Request) {
	var req service.EntropyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.ClientPublicKey == "" {
		writeError(w, http.StatusBadRequest, "client_public_key is required")
		return
	}

	resp, err := service.GenerateEncryptedEntropy(req.ClientPublicKey)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to generate entropy")
		return
	}

	writeJSON(w, http.StatusOK, resp)
}

func writeJSON(w http.ResponseWriter, status int, data any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, map[string]string{"error": message})
}
