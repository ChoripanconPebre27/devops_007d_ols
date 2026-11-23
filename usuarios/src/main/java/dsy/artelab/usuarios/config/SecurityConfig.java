package dsy.artelab.usuarios.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

import dsy.artelab.usuarios.repository.UsuarioRepository;
import dsy.artelab.usuarios.security.JwtAuthenticationFilter;

@Configuration
public class SecurityConfig {

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http, JwtAuthenticationFilter jwtAuthenticationFilter)
            throws Exception {
        return http
                .csrf(csrf -> csrf.disable())
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers("/api/v1/auth/**").permitAll()
                        .requestMatchers("/doc/**", "/doc.html", "/swagger-ui/**", "/v3/api-docs/**", "/swagger-resources/**", "/webjars/**", "/actuator/health", "/actuator/health/**", "/actuator/prometheus").permitAll()
                        // Endpoint interno que consume artelab (no envia JWT). En Kubernetes lo restringe
                        // una AuthorizationPolicy de Istio: solo la identidad (mTLS) de artelab puede llamarlo.
                        .requestMatchers(HttpMethod.GET, "/api/v1/usuarios/*/lookup").permitAll()
                        .anyRequest().authenticated())
                .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class)
                .build();
    }

    @Bean
    public UserDetailsService userDetailsService(UsuarioRepository usuarioRepository, PasswordEncoder passwordEncoder) {
        return correo -> usuarioRepository.findByCorreo(correo)
                .map(usuario -> User.withUsername(usuario.getCorreo())
                        .password(resolvePassword(usuario.getClave(), passwordEncoder))
                        .roles("USER")
                        .build())
                .orElseThrow(() -> new UsernameNotFoundException("Usuario no encontrado"));
    }

    private String resolvePassword(String storedPassword, PasswordEncoder passwordEncoder) {
        if (storedPassword != null && storedPassword.startsWith("$2")) {
            return storedPassword;
        }
        return passwordEncoder.encode(storedPassword);
    }

    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration configuration) throws Exception {
        return configuration.getAuthenticationManager();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
