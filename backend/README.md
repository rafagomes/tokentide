# Tokentide Backend

Tokentide is a blockchain-based gift store that allows users to send gifts, such as NFTs or tokens, to others. The platform supports artists who can submit their art to be gifted, and businesses or projects can use the platform to run giveaways or send promotional gifts. This platform is built using Fiber (Go) for the backend and Next.js for the frontend, following a clean architecture to ensure scalability and maintainability.

## Features

- Users can send NFTs or tokens as gifts.
- Monetization through referral systems, transfer fees, and artist commissions.
- Projects/Companies can use the platform to run giveaways or lotteries.
- Real-time interactions using WebSockets for features like live notifications and auctions.

## Project Structure

### cmd/
Contains the entry point of the application.

### cmd/api/
This is where the main application logic starts. It contains the main.go file that runs the Fiber server. 

### internal/
This folder contains all the core business logic, service layers, controllers (delivery), and domain logic of the application. The separation of concerns helps maintain a clean architecture and better scalability.

### internal/app/
Responsible for setting up the router and managing routes for the application. It acts as a centralized location for routing logic, where all API routes are defined and initialized.

### internal/delivery/
This layer handles the "delivery" of the business logic to external users. It manages HTTP requests and responses (controllers) and ensures that data flow between the user and the core application is properly handled.

### internal/delivery/http/
Contains HTTP handlers (controllers). These handlers are responsible for processing incoming API requests, calling the appropriate service methods, and returning responses to the clients.

### internal/domain/
Contains core business entities (like Gifts, Users, Artists, etc.) and interfaces for repositories and services. This is the most critical part of the application, defining business rules and ensuring independence from any specific frameworks or external libraries.

### internal/repository/
This layer contains the repository implementations, responsible for database interactions. It abstracts the data access logic, ensuring that the service layer can interact with the data without needing to know about the database details.

### internal/service/
Implements business logic by interacting with the domain and repository layers. It contains service methods that process the data and orchestrate the business operations, ensuring the business rules are respected.

### pkg/
This folder contains utility packages that can be reused across the application. In this case, it handles configuration management such as environment variables or application settings.

### pkg/config/
Contains logic for loading and managing application configurations, such as reading from `.env` files and providing configuration values throughout the application.

## Getting Started

### Prerequisites

- Go 1.19+
- PostgreSQL or any other database you prefer
- Docker (Optional, for containerization)

### Installation

1. Clone the repository:
```bash
git clone https:github.com/your-username/tokentide.git
```

2. Navigate to the project directory:
```bash
cd tokentide
```

3. Install dependencies:
```bash
go mod tidy
```

4. Set up environment variables by creating a `.env` file in the root directory:
```bash
cp .env.example .env
```

Fill in the necessary environment variables, such as database credentials.

5. Run the application:
```bash
go run cmd/api/main.go
```

The application should now be running at `http:ocalhost:3000/`.

## Usage

- Access the health check endpoint: `http:ocalhost:3000/health` to ensure the server is running properly.

## Contributing

Contributions are welcome! Feel free to submit pull requests, open issues, or suggest features.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
