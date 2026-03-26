package handler

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"net/url"
	"regexp"
	"sync"
	"time"

	_ "modernc.org/sqlite"
)

type Notify struct {
	db      *sql.DB
	mu      sync.Mutex
	limiter map[string][]time.Time
}

var emailRegex = regexp.MustCompile(`^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$`)

func NewNotify() *Notify {
	db, err := sql.Open("sqlite", "/data/subscribers.db")
	if err != nil {
		log.Fatalf("failed to open subscribers db: %v", err)
	}

	db.Exec(`CREATE TABLE IF NOT EXISTS subscribers (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		email TEXT UNIQUE NOT NULL,
		ip TEXT NOT NULL,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP
	)`)

	return &Notify{
		db:      db,
		limiter: make(map[string][]time.Time),
	}
}

func (n *Notify) Subscribe(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Email string `json:"email"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	if !emailRegex.MatchString(req.Email) {
		writeError(w, http.StatusBadRequest, "invalid email format")
		return
	}

	ip, _, _ := net.SplitHostPort(r.RemoteAddr)
	if ip == "" {
		ip = r.RemoteAddr
	}
	if fwd := r.Header.Get("X-Forwarded-For"); fwd != "" {
		ip = fwd
	}

	if n.isRateLimited(ip) {
		writeError(w, http.StatusTooManyRequests, "too many requests")
		return
	}

	var exists bool
	n.db.QueryRow("SELECT EXISTS(SELECT 1 FROM subscribers WHERE email = ?)", req.Email).Scan(&exists)

	if exists {
		writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
		return
	}

	_, err := n.db.Exec("INSERT INTO subscribers (email, ip) VALUES (?, ?)", req.Email, ip)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to save")
		return
	}

	go n.sendTelegram(req.Email, ip)

	writeJSON(w, http.StatusOK, map[string]bool{"ok": true})
}

func (n *Notify) isRateLimited(ip string) bool {
	n.mu.Lock()
	defer n.mu.Unlock()

	now := time.Now()
	cutoff := now.Add(-time.Hour)

	times := n.limiter[ip]
	filtered := make([]time.Time, 0, len(times))
	for _, t := range times {
		if t.After(cutoff) {
			filtered = append(filtered, t)
		}
	}

	if len(filtered) >= 3 {
		n.limiter[ip] = filtered
		return true
	}

	n.limiter[ip] = append(filtered, now)
	return false
}

func (n *Notify) sendTelegram(email, ip string) {
	botToken := "8789382549:AAF2b6x9Bx0aNqfh4QwClISzpXXl9mQnc2o"
	chatID := "7578281292"
	ts := time.Now().UTC().Format("02.01.2006 | 15:04")
	text := fmt.Sprintf("💎 *New subscriber*\n\n`%s`\n%s", email, ts)

	tgURL := fmt.Sprintf("https://api.telegram.org/bot%s/sendMessage?chat_id=%s&parse_mode=Markdown&text=%s",
		botToken, chatID, url.QueryEscape(text))

	resp, err := http.Get(tgURL)
	if err != nil {
		log.Printf("telegram send failed: %v", err)
		return
	}
	resp.Body.Close()
}
