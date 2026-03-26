package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
)

func main() {
	secret := os.Getenv("WEBHOOK_SECRET")
	if secret == "" {
		log.Fatal("WEBHOOK_SECRET is required")
	}

	http.HandleFunc("POST /webhook", func(w http.ResponseWriter, r *http.Request) {
		body, err := io.ReadAll(r.Body)
		if err != nil {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}

		sig := r.Header.Get("X-Hub-Signature-256")
		if !verifySignature(body, sig, secret) {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}

		log.Println("deploy triggered")
		cmd := exec.Command("/opt/tonly/backend/deploy/deploy.sh")
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Start(); err != nil {
			log.Printf("deploy error: %v", err)
			http.Error(w, "deploy failed", http.StatusInternalServerError)
			return
		}

		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	log.Println("webhook listener on :9000")
	log.Fatal(http.ListenAndServe(":9000", nil))
}

func verifySignature(payload []byte, signature, secret string) bool {
	if len(signature) < 8 {
		return false
	}

	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(payload)
	expected := "sha256=" + hex.EncodeToString(mac.Sum(nil))
	return hmac.Equal([]byte(expected), []byte(signature))
}
