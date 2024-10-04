package main

import (
	"log"
	"tokentide/internal/app"
	"tokentide/pkg/config"
)

func main() {
	config.LoadConfig()

	db, err := config.SetupDatabase()
	if err != nil {
		log.Fatalf("Could not connect to the database: %v", err)
	}

	// Automatically migrate the database (optional, depending on your entities)
	db.AutoMigrate( /* Add your models here */ )

	// Setup and run Fiber router
	router := app.SetupRouter()
	log.Fatal(router.Listen(":3000"))
}
