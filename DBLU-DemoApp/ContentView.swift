//
//  ContentView.swift
//  DBLU-DemoApp
//
//  Created by fausto.dassenno on 07/10/25.
//

import SwiftUI
import DBLUSDK

struct ContentView: View {
    @State private var sdk: DBLUSDK
    @State private var resultText = "Tap a button to test the API"
    @State private var isLoading = false
    @State private var isLoadingMCP = false
    @State private var isLoadingDoubles = false
    @State private var isLoadingPrompt = false
    @State private var mcpToken = ""
    @State private var promptText = ""
    @State private var partnerKey = ""
    @State private var selectedDoubleId: String? = nil
    @State private var availableDoubles: [PersonaVault] = []
    
    init() {
        // Initialize SDK with appropriate base URL based on simulator vs device
        #if targetEnvironment(simulator)
        _sdk = State(initialValue: DBLUSDK(baseURL: "http://127.0.0.1:8000"))
        #else
        _sdk = State(initialValue: DBLUSDK(baseURL: "https://api.dblu.ai"))
        #endif
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("DBLU SDK Demo")
                    .font(.title)
                    .fontWeight(.bold)
                
                // API Health Check Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("API Health Check")
                        .font(.headline)
                    
                    Button(action: {
                        Task {
                            await testAPI()
                        }
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isLoading ? "Testing..." : "Test API Health")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isLoading || isLoadingMCP || isLoadingDoubles || isLoadingPrompt)
                }
                
                Divider()
                
                // MCP Token Authentication Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("MCP Token Authentication")
                        .font(.headline)
                    
                    TextField("Enter MCP Token", text: $mcpToken)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Button(action: {
                        Task {
                            await testMCPToken()
                        }
                    }) {
                        HStack {
                            if isLoadingMCP {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isLoadingMCP ? "Testing..." : "Test MCP Token")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(mcpToken.isEmpty ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(mcpToken.isEmpty || isLoading || isLoadingMCP || isLoadingDoubles || isLoadingPrompt)
                }
                
                Divider()
                
                // List Doubles Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("List All Doubles")
                        .font(.headline)
                    
                    Button(action: {
                        Task {
                            await listDoubles()
                        }
                    }) {
                        HStack {
                            if isLoadingDoubles {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isLoadingDoubles ? "Loading..." : "List Doubles")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(mcpToken.isEmpty ? Color.gray : Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(mcpToken.isEmpty || isLoading || isLoadingMCP || isLoadingDoubles)
                }
                
                Divider()
                
                // Execute Prompt Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Execute Prompt with OpenAI")
                        .font(.headline)
                    
                    TextField("Partner Key", text: $partnerKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    TextField("Enter your prompt", text: $promptText, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                        .autocapitalization(.sentences)
                    
                    HStack {
                        Text("Use specific double:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("Double", selection: $selectedDoubleId) {
                            Text("All Doubles").tag(String?.none)
                            ForEach(availableDoubles, id: \.personaId) { double in
                                Text(double.name).tag(String?.some(double.personaId))
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(availableDoubles.isEmpty)
                    }
                    
                    Button(action: {
                        Task {
                            await executePrompt()
                        }
                    }) {
                        HStack {
                            if isLoadingPrompt {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isLoadingPrompt ? "Executing..." : "Execute Prompt")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background((mcpToken.isEmpty || promptText.isEmpty || partnerKey.isEmpty) ? Color.gray : Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(mcpToken.isEmpty || promptText.isEmpty || partnerKey.isEmpty || isLoading || isLoadingMCP || isLoadingDoubles || isLoadingPrompt)
                }
                
                // Results Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Results")
                        .font(.headline)
                    
                    ScrollView {
                        Text(resultText)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .frame(minHeight: 150, maxHeight: 300)
                }
            }
            .padding()
        }
    }
    
    private func testAPI() async {
        isLoading = true
        resultText = "Testing API connection..."
        
        do {
            // Create a custom request to get the full response
            guard let url = URL(string: "\(sdk.baseURL)/health") else {
                resultText = "❌ Invalid URL: \(sdk.baseURL)/health"
                isLoading = false
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("DBLUSDK/1.0.0", forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                resultText = "❌ Invalid response received"
                isLoading = false
                return
            }
            
            let statusCode = httpResponse.statusCode
            let responseString = String(data: data, encoding: .utf8) ?? "No response data"
            
            if statusCode == 200 {
                resultText = """
                ✅ API Health Check Successful!
                
                Status Code: \(statusCode)
                Response: \(responseString)
                
                Timestamp: \(Date())
                Base URL: \(sdk.baseURL)
                """
            } else {
                resultText = """
                ❌ API Health Check Failed
                
                Status Code: \(statusCode)
                Response: \(responseString)
                
                Timestamp: \(Date())
                Base URL: \(sdk.baseURL)
                """
            }
            
        } catch {
            resultText = """
            ❌ Network Error
            
            Error: \(error.localizedDescription)
            Timestamp: \(Date())
            Base URL: \(sdk.baseURL)
            """
        }
        
        isLoading = false
    }
    
    private func testMCPToken() async {
        isLoadingMCP = true
        resultText = "Testing MCP token authentication..."
        
        guard !mcpToken.isEmpty else {
            resultText = "❌ Please enter an MCP token"
            isLoadingMCP = false
            return
        }
        
        do {
            let result = try await sdk.testMCPTokenAuth(mcpToken: mcpToken)
            
            if result.isAuthenticated {
                var userInfoText = ""
                if let userInfo = result.userInfo {
                    userInfoText = """
                    
                    User Information:
                    • ID: \(userInfo.id.uuidString)
                    • Name: \(userInfo.firstName) \(userInfo.lastName)
                    • Email: \(userInfo.email)
                    • Email Verified: \(userInfo.emailVerified ? "Yes" : "No")
                    • Searchable: \(userInfo.searchable ? "Yes" : "No")
                    """
                    if let profilePic = userInfo.profilePictureUrl {
                        userInfoText += "\n• Profile Picture: \(profilePic)"
                    }
                }
                
                resultText = """
                ✅ MCP Token Authentication Successful!
                
                Token: \(String(mcpToken.prefix(20)))...
                Timestamp: \(Date())
                Base URL: \(sdk.baseURL)
                \(userInfoText)
                """
            } else {
                resultText = """
                ❌ MCP Token Authentication Failed
                
                Token: \(String(mcpToken.prefix(20)))...
                Error: \(result.error ?? "Unknown error")
                Timestamp: \(Date())
                Base URL: \(sdk.baseURL)
                """
            }
        } catch let error as NetworkError {
            var errorDetails = ""
            switch error {
            case .invalidURL:
                errorDetails = "Invalid URL"
            case .invalidResponse:
                errorDetails = "Invalid response received"
            case .httpError(let statusCode):
                errorDetails = "HTTP Error: \(statusCode)"
            case .decodingError(let decodingError):
                errorDetails = "Decoding Error: \(decodingError.localizedDescription)"
            case .noData:
                errorDetails = "No data received"
            case .networkUnavailable:
                errorDetails = "Network unavailable"
            }
            
            resultText = """
            ❌ Network Error
            
            Token: \(String(mcpToken.prefix(20)))...
            Error: \(errorDetails)
            Timestamp: \(Date())
            Base URL: \(sdk.baseURL)
            """
        } catch {
            resultText = """
            ❌ Unexpected Error
            
            Token: \(String(mcpToken.prefix(20)))...
            Error: \(error.localizedDescription)
            Timestamp: \(Date())
            Base URL: \(sdk.baseURL)
            """
        }
        
        isLoadingMCP = false
    }
    
    private func listDoubles() async {
        isLoadingDoubles = true
        resultText = "Loading doubles..."
        
        guard !mcpToken.isEmpty else {
            resultText = "❌ Please enter an MCP token first"
            isLoadingDoubles = false
            return
        }
        
        do {
            let doubles = try await sdk.listDoubles(mcpToken: mcpToken)
            
            // Store doubles for prompt execution
            availableDoubles = doubles
            
            if doubles.isEmpty {
                resultText = """
                ✅ Successfully retrieved doubles list
                
                Found 0 doubles in your vault.
                
                Token: \(String(mcpToken.prefix(20)))...
                Timestamp: \(Date())
                Base URL: \(sdk.baseURL)
                """
            } else {
                var doublesList = ""
                for (index, double) in doubles.enumerated() {
                    doublesList += """
                    
                    [\(index + 1)] \(double.name)
                    • Persona ID: \(double.personaId)
                    • Vault ID: \(double.id.uuidString)
                    • Created: \(formatDate(double.createdAt))
                    • Updated: \(formatDate(double.updatedAt))
                    """
                }
                
                resultText = """
                ✅ Successfully retrieved doubles list!
                
                Found \(doubles.count) double\(doubles.count == 1 ? "" : "s") in your vault:
                \(doublesList)
                
                Token: \(String(mcpToken.prefix(20)))...
                Timestamp: \(Date())
                Base URL: \(sdk.baseURL)
                """
            }
        } catch let error as NetworkError {
            var errorDetails = ""
            switch error {
            case .invalidURL:
                errorDetails = "Invalid URL"
            case .invalidResponse:
                errorDetails = "Invalid response received"
            case .httpError(let statusCode):
                if statusCode == 401 {
                    errorDetails = "HTTP 401 - Authentication failed (invalid MCP token)"
                } else {
                    errorDetails = "HTTP Error: \(statusCode)"
                }
            case .decodingError(let decodingError):
                var details = "Decoding Error: \(decodingError.localizedDescription)"
                // Try to extract more details from the error
                if let nsError = decodingError as NSError? {
                    if let responseData = nsError.userInfo["Response"] as? String {
                        details += "\n\nRaw Response: \(responseData.prefix(500))"
                    }
                    if let decodingInfo = nsError.userInfo["DecodingError"] as? String {
                        details += "\n\nDetails: \(decodingInfo)"
                    }
                }
                errorDetails = details
            case .noData:
                errorDetails = "No data received"
            case .networkUnavailable:
                errorDetails = "Network unavailable"
            }
            
            resultText = """
            ❌ Error Loading Doubles
            
            Token: \(String(mcpToken.prefix(20)))...
            Error: \(errorDetails)
            Timestamp: \(Date())
            Base URL: \(sdk.baseURL)
            """
        } catch {
            resultText = """
            ❌ Unexpected Error
            
            Token: \(String(mcpToken.prefix(20)))...
            Error: \(error.localizedDescription)
            Timestamp: \(Date())
            Base URL: \(sdk.baseURL)
            """
        }
        
        isLoadingDoubles = false
    }
    
    private func executePrompt() async {
        isLoadingPrompt = true
        resultText = "Executing prompt..."
        
        guard !mcpToken.isEmpty else {
            resultText = "❌ Please enter an MCP token first"
            isLoadingPrompt = false
            return
        }
        
        guard !partnerKey.isEmpty else {
            resultText = "❌ Please enter a partner key"
            isLoadingPrompt = false
            return
        }
        
        guard !promptText.isEmpty else {
            resultText = "❌ Please enter a prompt"
            isLoadingPrompt = false
            return
        }
        
        do {
            let response = try await sdk.executePrompt(
                mcpToken: mcpToken,
                prompt: promptText,
                partnerKey: partnerKey,
                doubleId: selectedDoubleId
            )
            
            if response.success {
                var contextInfo = ""
                if let doubleId = selectedDoubleId {
                    if let selectedDouble = availableDoubles.first(where: { $0.personaId == doubleId }) {
                        contextInfo = "\n\nContext: Using double '\(selectedDouble.name)' (ID: \(doubleId))"
                    } else {
                        contextInfo = "\n\nContext: Using double ID: \(doubleId)"
                    }
                } else {
                    contextInfo = "\n\nContext: Using all doubles from vault"
                }
                
                var tokenInfo = ""
                if let totalTokens = response.totalTokens {
                    tokenInfo = "\n\nToken Usage:"
                    if let promptTokens = response.promptTokens {
                        tokenInfo += "\n  Prompt: \(promptTokens) tokens"
                    }
                    if let completionTokens = response.completionTokens {
                        tokenInfo += "\n  Completion: \(completionTokens) tokens"
                    }
                    tokenInfo += "\n  Total: \(totalTokens) tokens"
                }
                
                resultText = """
                ✅ Prompt Executed Successfully!
                
                Prompt: \(promptText)
                \(contextInfo)
                
                AI Response:
                \(response.response ?? "No response received")
                \(tokenInfo)
                
                User ID: \(response.userId ?? "Unknown")
                Timestamp: \(Date())
                Base URL: \(sdk.baseURL)
                """
            } else {
                resultText = """
                ❌ Prompt Execution Failed
                
                Prompt: \(promptText)
                Error: \(response.error ?? "Unknown error")
                User ID: \(response.userId ?? "Unknown")
                Timestamp: \(Date())
                Base URL: \(sdk.baseURL)
                """
            }
        } catch let error as NetworkError {
            var errorDetails = ""
            switch error {
            case .invalidURL:
                errorDetails = "Invalid URL"
            case .invalidResponse:
                errorDetails = "Invalid response received"
            case .httpError(let statusCode):
                if statusCode == 401 {
                    errorDetails = "HTTP 401 - Authentication failed (invalid MCP token)"
                } else {
                    errorDetails = "HTTP Error: \(statusCode)"
                }
            case .decodingError(let decodingError):
                var details = "Decoding Error: \(decodingError.localizedDescription)"
                if let nsError = decodingError as NSError? {
                    if let responseData = nsError.userInfo["Response"] as? String {
                        details += "\n\nRaw Response: \(responseData.prefix(500))"
                    }
                }
                errorDetails = details
            case .noData:
                errorDetails = "No data received"
            case .networkUnavailable:
                errorDetails = "Network unavailable"
            }
            
            resultText = """
            ❌ Error Executing Prompt
            
            Prompt: \(promptText)
            Error: \(errorDetails)
            Timestamp: \(Date())
            Base URL: \(sdk.baseURL)
            """
        } catch {
            resultText = """
            ❌ Unexpected Error
            
            Prompt: \(promptText)
            Error: \(error.localizedDescription)
            Timestamp: \(Date())
            Base URL: \(sdk.baseURL)
            """
        }
        
        isLoadingPrompt = false
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    ContentView()
}
