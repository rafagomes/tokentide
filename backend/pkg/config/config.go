package config

import (
	"fmt"
	"log"
	"os"

	"github.com/joho/godotenv"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

// LoadConfig loads environment variables from the .env file
func LoadConfig() {
	err := godotenv.Load()
	if err != nil {
		log.Printf("Error loading .env file")
	}
}

// GetEnv returns the value of an environment variable
func GetEnv(key string) string {
	return os.Getenv(key)
}

// SetupDatabase connects to PostgreSQL
func SetupDatabase() (*gorm.DB, error) {
	dbHost := GetEnv("DB_HOST")
	dbPort := GetEnv("DB_PORT")
	dbUser := GetEnv("DB_USER")
	dbPassword := GetEnv("DB_PASSWORD")
	dbName := GetEnv("DB_NAME")

	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		dbHost, dbPort, dbUser, dbPassword, dbName)

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		return nil, err
	}

	return db, nil
}
