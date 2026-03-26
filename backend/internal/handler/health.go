package handler

import (
	"encoding/json"
	"net/http"
)

type Health struct{}

func NewHealth() *Health {
	return &Health{}
}

func (h *Health) Check(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status": "ok",
	})
}
