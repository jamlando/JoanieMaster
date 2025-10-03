import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel: AuthenticationViewModel
    @State private var showingRegisterView = false
    @State private var showingForgotPasswordView = false
    
    init(authService: AuthService) {
        self._viewModel = StateObject(wrappedValue: AuthenticationViewModel(authService: authService))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "paintbrush.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Welcome to Joanie")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Preserve and celebrate your child's creative journey")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    // Login Form
                    VStack(spacing: 16) {
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
                        }
                        
                        // Forgot Password Button
                        HStack {
                            Spacer()
                            Button("Forgot Password?") {
                                showingForgotPasswordView = true
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Sign In Button
                    Button(action: {
                        Task {
                            await viewModel.signIn()
                        }
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.right.circle.fill")
                            }
                            Text("Sign In")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isSignInValid ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!viewModel.isSignInValid || viewModel.isLoading)
                    .padding(.horizontal, 24)
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray.opacity(0.3))
                        
                        Text("or")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                        
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray.opacity(0.3))
                    }
                    .padding(.horizontal, 24)
                    
                    // Apple Sign In Button
                    Button(action: {
                        Task {
                            await viewModel.signInWithApple()
                        }
                    }) {
                        HStack {
                            Image(systemName: "applelogo")
                                .font(.title2)
                            Text("Continue with Apple")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isLoading)
                    .padding(.horizontal, 24)
                    
                    // Sign Up Link
                    HStack {
                        Text("Don't have an account?")
                            .foregroundColor(.secondary)
                        
                        Button("Sign Up") {
                            showingRegisterView = true
                        }
                        .foregroundColor(.blue)
                        .font(.subheadline)
                    }
                    .padding(.top, 16)
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationBarHidden(true)
            .alert("Authentication", isPresented: $viewModel.showingAlert) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .sheet(isPresented: $showingRegisterView) {
                RegisterView(authService: viewModel.getAuthService())
            }
            .sheet(isPresented: $showingForgotPasswordView) {
                ForgotPasswordView(authService: viewModel.getAuthService())
            }
        }
    }
}

#Preview {
    LoginView(authService: AuthService(supabaseService: SupabaseService.shared, emailServiceManager: DependencyContainer.shared.emailServiceManager))
}
