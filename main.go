package main

import (
	"fmt"
	"io"
	"log"
	"net/mail"
	"os"
	"time"

	"github.com/emersion/go-smtp"
)

type backend struct{}

func (b *backend) NewSession(_ *smtp.Conn) (smtp.Session, error) {
	return &session{}, nil
}

type session struct {
	from string
	to   []string
}

func (s *session) AuthPlain(username, password string) error {
	return nil
}

func (s *session) Mail(from string, opts *smtp.MailOptions) error {
	s.from = from
	return nil
}

func (s *session) Rcpt(to string, opts *smtp.RcptOptions) error {
	s.to = append(s.to, to)
	return nil
}

func (s *session) Data(r io.Reader) error {
	msg, err := mail.ReadMessage(r)
	if err != nil {
		log.Printf("[%s] ERROR parsing message: %v", time.Now().Format(time.RFC3339), err)
		return nil
	}

	subject := msg.Header.Get("Subject")

	log.Printf("EMAIL RECEIVED | from=%s | to=%v | subject=%q | time=%s",
		s.from, s.to, subject, time.Now().Format(time.RFC3339))

	// Discard the rest of the body
	io.Copy(io.Discard, msg.Body)
	return nil
}

func (s *session) Reset() {
	s.from = ""
	s.to = nil
}

func (s *session) Logout() error {
	return nil
}

func main() {
	port := os.Getenv("SMTP_PORT")
	if port == "" {
		port = "587"
	}

	domain := os.Getenv("SMTP_DOMAIN")
	if domain == "" {
		domain = "localhost"
	}

	be := &backend{}

	srv := smtp.NewServer(be)
	srv.Addr = fmt.Sprintf(":%s", port)
	srv.Domain = domain
	srv.AllowInsecureAuth = true
	srv.MaxMessageBytes = 10 * 1024 * 1024 // 10 MB
	srv.ReadTimeout = 30 * time.Second
	srv.WriteTimeout = 30 * time.Second

	log.Printf("Starting SMTP server on port %s (domain: %s)", port, domain)
	if err := srv.ListenAndServe(); err != nil {
		log.Fatal(err)
	}
}
