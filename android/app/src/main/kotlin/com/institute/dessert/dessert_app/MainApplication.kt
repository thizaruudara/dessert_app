package com.institute.dessert.dessert_app

import io.flutter.app.FlutterApplication

class MainApplication : FlutterApplication() {
    override fun onCreate() {
        // Enforce IPv4 priority at the earliest JVM lifecycle moment
        // to bypass IPv6 DNS/routing packet drop on Sri Lankan SLT Fiber & Dialog Wi-Fi routers
        try {
            System.setProperty("java.net.preferIPv4Stack", "true")
            System.setProperty("java.net.preferIPv6Addresses", "false")
        } catch (e: Exception) {
            e.printStackTrace()
        }
        super.onCreate()
    }
}
