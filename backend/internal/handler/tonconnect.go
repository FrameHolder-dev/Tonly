package handler

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"
)

type TonConnect struct {
	mu       sync.RWMutex
	sessions map[string]*ConnectSession
}

type ConnectSession struct {
	ID        string
	Messages  []ConnectMessage
	Clients   []chan ConnectMessage
	CreatedAt time.Time
}

type ConnectMessage struct {
	From    string `json:"from"`
	Message string `json:"message"`
}

func NewTonConnect() *TonConnect {
	tc := &TonConnect{
		sessions: make(map[string]*ConnectSession),
	}
	go tc.cleanup()
	return tc
}

func (h *TonConnect) cleanup() {
	for {
		time.Sleep(5 * time.Minute)
		h.mu.Lock()
		now := time.Now()
		for id, s := range h.sessions {
			if now.Sub(s.CreatedAt) > 10*time.Minute {
				for _, ch := range s.Clients {
					close(ch)
				}
				delete(h.sessions, id)
			}
		}
		h.mu.Unlock()
	}
}

func (h *TonConnect) Bridge(w http.ResponseWriter, r *http.Request) {
	clientID := r.URL.Query().Get("client_id")

	switch r.Method {
	case http.MethodGet:
		h.subscribe(w, r, clientID)
	case http.MethodPost:
		h.send(w, r, clientID)
	default:
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (h *TonConnect) subscribe(w http.ResponseWriter, r *http.Request, clientID string) {
	if clientID == "" {
		b := make([]byte, 16)
		rand.Read(b)
		clientID = hex.EncodeToString(b)
	}

	h.mu.Lock()
	session, exists := h.sessions[clientID]
	if !exists {
		session = &ConnectSession{
			ID:        clientID,
			CreatedAt: time.Now(),
		}
		h.sessions[clientID] = session
	}

	ch := make(chan ConnectMessage, 10)
	session.Clients = append(session.Clients, ch)
	h.mu.Unlock()

	flusher, ok := w.(http.Flusher)
	if !ok {
		writeError(w, http.StatusInternalServerError, "streaming not supported")
		return
	}

	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("Access-Control-Allow-Origin", "*")

	fmt.Fprintf(w, "event: open\ndata: {\"id\":\"%s\"}\n\n", clientID)
	flusher.Flush()

	for {
		select {
		case msg, ok := <-ch:
			if !ok {
				return
			}
			data, _ := json.Marshal(msg)
			fmt.Fprintf(w, "event: message\ndata: %s\n\n", string(data))
			flusher.Flush()
		case <-r.Context().Done():
			h.mu.Lock()
			if s, exists := h.sessions[clientID]; exists {
				for i, c := range s.Clients {
					if c == ch {
						s.Clients = append(s.Clients[:i], s.Clients[i+1:]...)
						break
					}
				}
			}
			h.mu.Unlock()
			return
		}
	}
}

func (h *TonConnect) send(w http.ResponseWriter, r *http.Request, clientID string) {
	to := r.URL.Query().Get("to")
	if to == "" {
		writeError(w, http.StatusBadRequest, "to is required")
		return
	}

	var msg ConnectMessage
	if err := json.NewDecoder(r.Body).Decode(&msg); err != nil {
		msg.From = clientID
		msg.Message = ""
	}
	if msg.From == "" {
		msg.From = clientID
	}

	h.mu.RLock()
	session, exists := h.sessions[to]
	h.mu.RUnlock()

	if !exists {
		h.mu.Lock()
		session = &ConnectSession{
			ID:        to,
			CreatedAt: time.Now(),
		}
		h.sessions[to] = session
		h.mu.Unlock()
	}

	h.mu.RLock()
	for _, ch := range session.Clients {
		select {
		case ch <- msg:
		default:
		}
	}
	h.mu.RUnlock()

	session.Messages = append(session.Messages, msg)

	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (h *TonConnect) GetManifest(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, map[string]any{
		"url":              "https://tonly.one",
		"name":             "Tonly",
		"iconUrl":          "https://tonly.one/assets/logo.svg",
		"termsOfUseUrl":    "https://tonly.one/en/terms",
		"privacyPolicyUrl": "https://tonly.one/en/privacy",
	})
}
