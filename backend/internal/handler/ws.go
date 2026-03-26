package handler

import (
	"log"
	"net/http"
	"sync"

	"golang.org/x/net/websocket"
)

type WSHub struct {
	clients map[*websocket.Conn]string
	mu      sync.RWMutex
}

func NewWSHub() *WSHub {
	return &WSHub{
		clients: make(map[*websocket.Conn]string),
	}
}

func (h *WSHub) Handler() http.Handler {
	return websocket.Handler(func(ws *websocket.Conn) {
		defer ws.Close()

		var address string
		if err := websocket.Message.Receive(ws, &address); err != nil {
			return
		}

		h.mu.Lock()
		h.clients[ws] = address
		h.mu.Unlock()

		log.Printf("ws: client connected for %s", address)

		defer func() {
			h.mu.Lock()
			delete(h.clients, ws)
			h.mu.Unlock()
			log.Printf("ws: client disconnected for %s", address)
		}()

		for {
			var msg string
			if err := websocket.Message.Receive(ws, &msg); err != nil {
				break
			}
		}
	})
}

func (h *WSHub) Broadcast(address string, message string) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	for conn, addr := range h.clients {
		if addr == address {
			websocket.Message.Send(conn, message)
		}
	}
}

func (h *WSHub) BroadcastAll(message string) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	for conn := range h.clients {
		websocket.Message.Send(conn, message)
	}
}
