# DBLU SDK Demo App

A demonstration iOS app showcasing how to integrate and use the DBLU SDK in your SwiftUI applications.

## How to Implement the SDK

This guide will walk you through integrating the DBLU SDK into your iOS or macOS application.

### Prerequisites

- Xcode 14.0 or later
- iOS 13.0+ or macOS 10.15+
- Swift 5.9+

### Installation

#### Option 1: Local Package (Development)

If you're working with the SDK locally (as in this demo app):

1. **Add the Package to Your Project**
   - Open your Xcode project
   - Select your project in the Project Navigator
   - Go to the **Package Dependencies** tab
   - Click the **+** button
   - Click **Add Local...**
   - Navigate to the `SDK` directory and select it
   - Click **Add Package**

2. **Add to Your Target**
   - In the same Package Dependencies section
   - Under your app target, ensure `DBLUSDK` is checked
   - Click **Add Package**

#### Option 2: Remote Package (Production)

If you're using the published SDK from GitHub:

1. **Add the Package to Your Project**
   - Open your Xcode project
   - Select your project in the Project Navigator
   - Go to the **Package Dependencies** tab
   - Click the **+** button
   - Enter the repository URL: `https://github.com/dieffe/dblu_ios_sdk.git`
   - Select the version (e.g., `1.0.0` or `Up to Next Major Version`)
   - Click **Add Package**

2. **Add to Your Target**
   - Under your app target, ensure `DBLUSDK` is checked
   - Click **Add Package**

### Basic Setup

1. **Import the SDK**

   In any Swift file where you want to use the SDK:

   ```swift
   import DBLUSDK
   ```

2. **Initialize the SDK**

   Create an instance of the SDK. You can use the default API URL or specify a custom one:

   ```swift
   // Using default API URL (https://api.dblu.ai)
   let sdk = DBLUSDK()
   
   // Or with a custom API URL (useful for local development or staging)
   let sdk = DBLUSDK(baseURL: "http://127.0.0.1:8000")
   ```

   **Note:** For local development (simulator), you might want to use `http://127.0.0.1:8000`. For production or device testing, use `https://api.dblu.ai`.

### Usage Examples

#### 1. Health Check

Test if the API is accessible:

```swift
Task {
    let isHealthy = await sdk.ping()
    if isHealthy {
        print("✅ API is accessible")
    } else {
        print("❌ API is not accessible")
    }
}
```

#### 2. MCP Token Authentication

Authenticate using an MCP token and retrieve user information:

```swift
Task {
    do {
        let result = try await sdk.testMCPTokenAuth(mcpToken: "your-mcp-token-here")
        
        if result.isAuthenticated {
            print("✅ Authentication successful!")
            if let userInfo = result.userInfo {
                print("User ID: \(userInfo.id)")
                print("Name: \(userInfo.firstName) \(userInfo.lastName)")
                print("Email: \(userInfo.email)")
            }
        } else {
            print("❌ Authentication failed: \(result.error ?? "Unknown error")")
        }
    } catch let error as NetworkError {
        print("Error: \(error.localizedDescription)")
    } catch {
        print("Unexpected error: \(error)")
    }
}
```

#### 3. List All Doubles (Personas)

Retrieve all doubles from the user's vault:

```swift
Task {
    do {
        let doubles = try await sdk.listDoubles(mcpToken: "your-mcp-token-here")
        
        print("Found \(doubles.count) doubles:")
        for double in doubles {
            print("• \(double.name) (ID: \(double.personaId))")
            print("  Created: \(double.createdAt)")
        }
    } catch let error as NetworkError {
        switch error {
        case .httpError(401):
            print("❌ Authentication failed - invalid MCP token")
        default:
            print("Error: \(error.localizedDescription)")
        }
    } catch {
        print("Unexpected error: \(error)")
    }
}
```

#### 4. Execute Prompt with Double Context

Execute a prompt against OpenAI with optional double (persona) context:

```swift
Task {
    do {
        // First, get the list of doubles to get a persona_id
        let doubles = try await sdk.listDoubles(mcpToken: "your-mcp-token-here")
        
        if let firstDouble = doubles.first {
            // Execute with specific double context
            let response = try await sdk.executePrompt(
                mcpToken: "your-mcp-token-here",
                prompt: "What are my favorite hobbies?",
                partnerKey: "your-partner-key",
                doubleId: firstDouble.personaId
            )
            
            if response.success, let answer = response.response {
                print("✅ AI Response: \(answer)")
                
                // Access token usage information
                if let totalTokens = response.totalTokens {
                    print("Tokens used: \(totalTokens)")
                }
            } else {
                print("❌ Error: \(response.error ?? "Unknown error")")
            }
        }
        
        // Or execute with all personas as context (omit doubleId)
        let response2 = try await sdk.executePrompt(
            mcpToken: "your-mcp-token-here",
            prompt: "Tell me about myself",
            partnerKey: "your-partner-key"
        )
        
        if response2.success, let answer = response2.response {
            print("✅ AI Response: \(answer)")
        }
    } catch let error as NetworkError {
        switch error {
        case .httpError(401):
            print("❌ Authentication failed")
        case .httpError(403):
            print("❌ Invalid partner key")
        case .httpError(429):
            print("❌ Monthly token limit exceeded")
        default:
            print("Error: \(error.localizedDescription)")
        }
    } catch {
        print("Unexpected error: \(error)")
    }
}
```

### SwiftUI Integration Example

Here's how to use the SDK in a SwiftUI view (as demonstrated in this demo app):

```swift
import SwiftUI
import DBLUSDK

struct ContentView: View {
    @State private var sdk: DBLUSDK
    @State private var mcpToken = ""
    @State private var resultText = ""
    @State private var isLoading = false
    
    init() {
        // Initialize SDK with appropriate base URL
        #if targetEnvironment(simulator)
        _sdk = State(initialValue: DBLUSDK(baseURL: "http://127.0.0.1:8000"))
        #else
        _sdk = State(initialValue: DBLUSDK(baseURL: "https://api.dblu.ai"))
        #endif
    }
    
    var body: some View {
        VStack {
            TextField("Enter MCP Token", text: $mcpToken)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Button("Test Authentication") {
                Task {
                    await testAuthentication()
                }
            }
            .disabled(mcpToken.isEmpty || isLoading)
            
            Text(resultText)
                .padding()
        }
    }
    
    private func testAuthentication() async {
        isLoading = true
        resultText = "Testing..."
        
        do {
            let result = try await sdk.testMCPTokenAuth(mcpToken: mcpToken)
            
            if result.isAuthenticated {
                resultText = "✅ Authentication successful!"
            } else {
                resultText = "❌ Authentication failed: \(result.error ?? "Unknown error")"
            }
        } catch let error as NetworkError {
            resultText = "Error: \(error.localizedDescription)"
        } catch {
            resultText = "Unexpected error: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}
```

### Error Handling

The SDK uses a `NetworkError` enum for error handling:

```swift
do {
    // SDK method calls
} catch let error as NetworkError {
    switch error {
    case .invalidURL:
        print("Invalid URL")
    case .invalidResponse:
        print("Invalid response received")
    case .httpError(let statusCode):
        print("HTTP Error: \(statusCode)")
        // Common status codes:
        // 401 - Authentication failed
        // 403 - Invalid partner key
        // 429 - Monthly token limit exceeded
    case .decodingError(let decodingError):
        print("Decoding Error: \(decodingError.localizedDescription)")
    case .noData:
        print("No data received")
    case .networkUnavailable:
        print("Network unavailable")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

### Available SDK Methods

| Method | Description |
|--------|-------------|
| `ping()` | Check if the API is accessible |
| `testMCPTokenAuth(mcpToken:)` | Test MCP token authentication and get user info |
| `listDoubles(mcpToken:)` | List all doubles (personas) for the authenticated user |
| `executePrompt(mcpToken:prompt:partnerKey:doubleId:)` | Execute a prompt with OpenAI and optional double context |

### Response Models

- **MCPAuthTestResult**: Contains authentication status and user information
- **MCPUserInfo**: User information from MCP authentication
- **PersonaVault**: Double (Persona) information from the vault
- **PromptResponse**: Response from prompt execution with token usage information

### Requirements

- iOS 13.0+ or macOS 10.15+
- Swift 5.9+
- No external dependencies (uses Foundation framework only)

### Additional Resources

- [SDK README](../SDK/README.md) - Full SDK documentation
- [SDK Methods Documentation](../SDK/SDK_METHODS_DOCUMENTATION.md) - Detailed API reference

### Demo App Features

This demo app demonstrates:

- ✅ API health check
- ✅ MCP token authentication
- ✅ Listing all doubles (personas)
- ✅ Executing prompts with OpenAI
- ✅ Error handling
- ✅ Token usage tracking
- ✅ SwiftUI integration

### Getting Your MCP Token

To use the SDK, you'll need an MCP token. Contact the DBLU team or refer to the main DoubleU app documentation for information on how to obtain your MCP token.

### Support

For support and questions:
- Check the [SDK documentation](../SDK/README.md)
- Contact the DBLU team
- Create an issue in the repository
