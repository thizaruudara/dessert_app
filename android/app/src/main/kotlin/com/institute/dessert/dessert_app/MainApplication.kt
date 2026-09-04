package com.institute.dessert.dessert_app

import io.flutter.app.FlutterApplication

class MainApplication : FlutterApplication() {
    override fun onCreate() {
        // Enforce IPv4 address resolution priority while keeping full dual-stack
        // socket support active for VPNs (Cloudflare 1.1.1.1 WARP, ProtonVPN, WireGuard)
        // and cellular IPv6 tunnels.
        // NOTE: We do NOT set "java.net.preferIPv4Stack=true" because it disables
        // AF_INET6 sockets completely, which causes VPN tunnels to fail with SocketException.
        try {
            System.setProperty("java.net.preferIPv6Addresses", "false")
        } catch (e: Exception) {
            e.printStackTrace()
        }
        super.onCreate()
    }
}
