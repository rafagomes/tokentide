package app

import (
	"tokentide/internal/delivery/http"

	"github.com/gofiber/fiber/v2"
)

func SetupRouter() *fiber.App {
	app := fiber.New()

	// Health check endpoint
	app.Get("/healths", http.HealthCheck)

	return app
}
