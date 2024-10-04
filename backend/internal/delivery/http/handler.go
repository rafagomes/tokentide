package http

import (
	"github.com/gofiber/fiber/v2"
)

// HealthCheck endpoint
func HealthCheck(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{
		"message": "API is running",
	})
}
