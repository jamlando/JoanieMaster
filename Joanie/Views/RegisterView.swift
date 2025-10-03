import SwiftUI

struct RegisterView: View {
    @StateObject private var viewModel: AuthenticationViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(authService: AuthService) {
        self._viewModel = StateObject(wrappedValue: AuthenticationViewModel(authService: authService))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                        
                        Text("Create Account")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Join Joanie to start preserving your child's creative journey")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Registration Form
                    VStack(spacing: 16) {
                        // Full Name Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Full Name")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("Enter your full name", text: $viewModel.fullName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.words)
                                .disableAutocorrection(true)
                        }
                        
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("Enter your email", text: $viewModel.email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            SecureField("Enter your password", text: $viewModel.password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            if !viewModel.password.isEmpty && viewModel.password.count < 8 {
                                Text("Password must be at least 8 characters")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        // Confirm Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confirm Password")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            SecureField("Confirm your password", text: $viewModel.confirmPassword)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            if !viewModel.confirmPassword.isEmpty && viewModel.password != viewModel.confirmPassword {
                                Text("Passwords do not match")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Sign Up Button
                    Button(action: {
                        Task {
                            await viewModel.signUp()
                        }
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "person.badge.plus")
                            }
                            Text("Create Account")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isSignUpValid ? Color.green : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!viewModel.isSignUpValid || viewModel.isLoading)
                    .padding(.horizontal, 24)
                    
                    // Terms and Privacy
                    VStack(spacing: 8) {
                        Text("By creating an account, you agree to our")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 4) {
                            Button("Terms of Service") {
                                // TODO: Open terms of service
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            
                            Text("and")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("Privacy Policy") {
                                // TODO: Open privacy policy
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Sign Up")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Registration", isPresented: $viewModel.showingAlert) {
                Button("OK") {
                    viewModel.clearError()
                    if viewModel.errorMessage?.contains("sent") == true {
                        dismiss()
                    }
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}

#Preview {
    RegisterView(authService: AuthService(supabaseService: SupabaseService.shared, emailServiceManager: DependencyContainer.shared.emailServiceManager))
}
