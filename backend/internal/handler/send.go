package handler

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/FrameHolder-dev/Tonly/backend/internal/config"
)

type Send struct {
	apiKey  string
	baseURL string
	client  *http.Client
}

func NewSend() *Send {
	cfg := config.Load()
	return &Send{
		apiKey:  cfg.TonAPIKey,
		baseURL: cfg.TonAPIV3,
		client:  &http.Client{Timeout: 15 * time.Second},
	}
}

type SendRequest struct {
	BOC string `json:"boc"`
}

func (h *Send) SendTransaction(w http.ResponseWriter, r *http.Request) {
	var req SendRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if req.BOC == "" {
		writeError(w, http.StatusBadRequest, "boc is required")
		return
	}

	body, _ := json.Marshal(map[string]string{"boc": req.BOC})
	apiReq, err := http.NewRequestWithContext(r.Context(), http.MethodPost, h.baseURL+"/blockchain/message", bytes.NewReader(body))
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to create request")
		return
	}

	apiReq.Header.Set("Content-Type", "application/json")
	if h.apiKey != "" {
		apiReq.Header.Set("Authorization", "Bearer "+h.apiKey)
	}

	resp, err := h.client.Do(apiReq)
	if err != nil {
		writeError(w, http.StatusBadGateway, "failed to broadcast transaction")
		return
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)

	if resp.StatusCode != http.StatusOK {
		writeError(w, resp.StatusCode, fmt.Sprintf("broadcast failed: %s", string(respBody)))
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"ok":   true,
		"hash": string(respBody),
	})
}

func (h *Send) EstimateFee(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"fee":      "5000000",
		"currency": "nanoton",
	})
}
