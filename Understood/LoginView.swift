//
//  LoginView.swift
//  Understood
//
//  Created by Adam Blair on 2/24/26.
//

import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    let supabase = SupabaseService.shared
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App title
            Text("Understood")
                .font(Typography.hero)
                .foregroundStyle(.textPrimary)

            Text("Capture your patterns")
                .font(Typography.subtitle)
                .foregroundStyle(.textSecondary)

            Spacer()

            // Form fields
            VStack(spacing: 16) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                if let error = errorMessage {
                    Text(error)
                        .font(Typography.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    Task {
                        await signIn()
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Text("Sign In")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.black)
                .foregroundStyle(.white)
                .cornerRadius(8)
                .disabled(isLoading || email.isEmpty || password.isEmpty)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .background(Color.understoodCream)
    }
    
    private func signIn() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabase.signIn(email: email, password: password)
        } catch {
            errorMessage = "Sign in failed. Please check your credentials."
            print("Sign in error: \(error)")
        }
        
        isLoading = false
    }
}

#Preview {
    LoginView()
}
