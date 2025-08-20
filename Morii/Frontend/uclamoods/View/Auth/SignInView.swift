import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var router: MoodAppRouter
    @StateObject private var authService = AuthenticationService.shared
    
    @State private var email = ""
    @State private var password = ""
    
    @State private var isLoading = false
    @State private var feedbackMessage = ""
    @State private var showForgotPassword = false // This state variable controls the sheet
    @State private var showTermsOfService = false
    
    // Styling constants
    private let primaryButtonHeight: CGFloat = 52
    private let formHorizontalPadding: CGFloat = 24
    private let mainStackSpacing: CGFloat = 25
    
    // MARK: - Login Logic
    func attemptLogin() {
        guard !email.isEmpty && !password.isEmpty else {
            feedbackMessage = "Please enter both email and password"
            return
        }
        
        isLoading = true
        feedbackMessage = ""
        performHapticFeedback()
        
        Task {
            do {
                _ = try await authService.loginAndFetchProfile(email: email, password: password)
                
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    feedbackMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func performHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let feedback = UIImpactFeedbackGenerator(style: style)
        feedback.prepare()
        feedback.impactOccurred()
    }
    
    // MARK: - Body
    var body: some View {
        ZStack { // Apply sheet modifier here or to ScrollView
//            Color.black
//                .edgesIgnoringSafeArea(.all)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: mainStackSpacing) {
                    loginFormView
                }
                .padding(.bottom, 30)
            }
        }
        .animation(.interactiveSpring(response: 0.45, dampingFraction: 0.65, blendDuration: 0.2), value: email)
        .animation(.interactiveSpring(response: 0.45, dampingFraction: 0.65, blendDuration: 0.2), value: password)
        .animation(.easeInOut(duration: 0.3), value: isLoading)
        // Attach the sheet modifier to a View in the body
        .sheet(isPresented: $showForgotPassword) {
            NavigationView { // Assuming ForgotPasswordView might need a navigation bar
                ForgotPasswordView()
            }
        }
        .sheet(isPresented: $showTermsOfService) { // Sheet for Terms of Service
            TermsOfServiceView() // Your TermsOfServiceView
        }
    }
    
    // MARK: - Subviews
    @ViewBuilder
    private var loginFormView: some View {
        Spacer().frame(height: UIScreen.main.bounds.height * 0.03)
        
        Text("Morii")
            .font(.custom("Georgia", size: 48))
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.bottom, -20)
        
        Text("Moments That Stay")
            .font(.custom("Chivo", size: 20))
            .foregroundColor(Color.white.opacity(0.85))
            .padding(.bottom, mainStackSpacing / 2)
        
        VStack(alignment: .center, spacing: 18) {
            FormField(
                title: "Email Address",
                placeholder: "you@example.com",
                text: $email,
                keyboardType: .emailAddress,
                textContentType: .emailAddress
            )
            SecureFormField(
                title: "Password",
                placeholder: "Enter your password",
                text: $password,
                textContentType: .password
            )
            
            HStack {
                Spacer()
                Button(action: {
                    performHapticFeedback(style: .light)
                    showForgotPassword = true // This will trigger the sheet
                }) {
                    Text("Forgot Password?")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.7))
                        .underline()
                }
            }
            .padding(.top, -5)
        }
        .padding(.horizontal, formHorizontalPadding)
        
        // Error message
        if !feedbackMessage.isEmpty {
            Text(feedbackMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.red)
                .multilineTextAlignment(.center)
                .padding(.vertical, 10)
                .padding(.horizontal, formHorizontalPadding)
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            Spacer().frame(height: (mainStackSpacing / 1.5) + 24)
        }
        
        // Login button or loading indicator
        if isLoading {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
                .frame(height: primaryButtonHeight)
                .padding(.top, feedbackMessage.isEmpty ? mainStackSpacing / 2 : 0)
        } else {
            Button(action: attemptLogin) {
                Text("Log In")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: primaryButtonHeight)
                    .background(Color.white)
                    .cornerRadius(primaryButtonHeight / 3)
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            }
            .disabled(email.isEmpty || password.isEmpty || isLoading)
            .padding(.horizontal, formHorizontalPadding)
            .padding(.top, feedbackMessage.isEmpty ? mainStackSpacing / 2 : 0)
        }
        
        // Sign up navigation
        Button(action: {
            performHapticFeedback(style: .light)
            router.navigateToSignUp()
        }) {
            HStack(spacing: 4) {
                Text("Don't have an account?")
                    .font(.system(size: 15))
                    .foregroundColor(Color.white.opacity(0.6))
                Text("Sign Up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.9))
            }
        }
        .padding(.top, mainStackSpacing / 1.5)
        
        // Terms of Service Link - Placed after Sign Up and before the final Spacer
        HStack(spacing: 3) {
            Text("By using Morii, you agree to our")
                .font(.system(size: 12))
                .foregroundColor(Color.white.opacity(0.5))
            Button(action: {
                performHapticFeedback(style: .light)
                showTermsOfService = true
            }) {
                Text("Terms of Service.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.75))
                    .underline()
            }
        }
        .padding(.top, mainStackSpacing)
        .padding(.horizontal, formHorizontalPadding)
        
        Spacer()
    }
}

// MARK: - Form Components (keep your existing design)
struct FormField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var autocapitalization: UITextAutocapitalizationType = .none
    var disableAutocorrection: Bool = true
    
    private let fieldHeight: CGFloat = 50
    private let fieldCornerRadius: CGFloat = 10
    
    var placeholderColor: Color = Color.white.opacity(0.6)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.white.opacity(0.7))
            
            TextField(
                "", // Use an empty string for the main title
                text: $text,
                prompt: Text(placeholder).foregroundColor(placeholderColor) // Styled placeholder
            )              .font(.system(size: 16))
                .frame(height: fieldHeight)
                .padding(.horizontal)
                .foregroundColor(.white)
                .background(Color.white.opacity(0.3))
                .cornerRadius(fieldCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: fieldCornerRadius)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .autocapitalization(autocapitalization)
                .disableAutocorrection(disableAutocorrection)
        }
    }
}

struct SecureFormField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var textContentType: UITextContentType? = .newPassword
    
    private let fieldHeight: CGFloat = 50
    private let fieldCornerRadius: CGFloat = 10
    
    var placeholderColor: Color = Color.white.opacity(0.6) // Example color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.white.opacity(0.7))
            
            SecureField(
                "", // Use an empty string for the main title
                text: $text,
                prompt: Text(placeholder).foregroundColor(placeholderColor) // Styled placeholder
            )
            .font(.system(size: 16))
            .frame(height: fieldHeight)
            .padding(.horizontal)
            .foregroundColor(.white)
            .background(Color.white.opacity(0.3))
            .cornerRadius(fieldCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: fieldCornerRadius)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
            .textContentType(textContentType)
            .autocapitalization(.none)
            .disableAutocorrection(true)
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (0, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview
struct SignInView_Previews: PreviewProvider {
    static var previews: some View {
        SignInView()
            .environmentObject(MoodAppRouter())
    }
}
