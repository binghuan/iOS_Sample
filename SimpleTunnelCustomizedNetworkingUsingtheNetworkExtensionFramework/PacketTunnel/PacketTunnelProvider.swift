/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 This file contains the PacketTunnelProvider class. The PacketTunnelProvider class is a sub-class of NEPacketTunnelProvider, and is the integration point between the Network Extension framework and the SimpleTunnel tunneling protocol.
 */

import NetworkExtension
import SimpleTunnelServices
import os


/// A packet tunnel provider object.
class PacketTunnelProvider: NEPacketTunnelProvider, TunnelDelegate, ClientTunnelConnectionDelegate {
    
    // MARK: Properties
    
    /// A reference to the tunnel object.
    var tunnel: ClientTunnel?
    
    /// The single logical flow of packets through the tunnel.
    var tunnelConnection: ClientTunnelConnection?
    
    /// The completion handler to call when the tunnel is fully established.
    var pendingStartCompletion: ((Error?) -> Void)?
    
    /// The completion handler to call when the tunnel is fully disconnected.
    var pendingStopCompletion: (() -> Void)?
    
    // MARK: NEPacketTunnelProvider
    
    /// Begin the process of establishing the tunnel.
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        
        os_log("BH_Lin: +++ startTunnel +++")
        
        
        let newTunnel = ClientTunnel()
        newTunnel.delegate = self
        
        if let error = newTunnel.startTunnel(self) {
            completionHandler(error as NSError)
        }
        else {
            // Save the completion handler for when the tunnel is fully established.
            pendingStartCompletion = completionHandler
            tunnel = newTunnel
        }
        os_log("BH_Lin: --- startTunnel ---")
    }
    
    /// Begin the process of stopping the tunnel.
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        os_log("BH_Lin: +++ stopTunnel +++")
        
        // Clear out any pending start completion handler.
        pendingStartCompletion = nil
        
        // Save the completion handler for when the tunnel is fully disconnected.
        pendingStopCompletion = completionHandler
        tunnel?.closeTunnel()
        os_log("BH_Lin: --- stopTunnel ---")
    }
    
    /// Handle IPC messages from the app.
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        os_log("BH_Lin: +++ handleAppMessage +++")
        
        guard let messageString = NSString(data: messageData, encoding: String.Encoding.utf8.rawValue) else {
            completionHandler?(nil)
            return
        }
        
        os_log("BH_Lin: Got a message from the app: \(messageString)")
        simpleTunnelLog("Got a message from the app: \(messageString)")
        
        let responseData = "Hello app".data(using: String.Encoding.utf8)
        completionHandler?(responseData)
        os_log("BH_Lin: --- handleAppMessage ---")
    }
    
    // MARK: TunnelDelegate
    
    /// Handle the event of the tunnel connection being established.
    func tunnelDidOpen(_ targetTunnel: Tunnel) {
        os_log("BH_Lin: +++ tunnelDidOpen +++")
        
        // Open the logical flow of packets through the tunnel.
        let newConnection = ClientTunnelConnection(tunnel: tunnel!, clientPacketFlow: packetFlow, connectionDelegate: self)
        newConnection.open()
        tunnelConnection = newConnection
        os_log("BH_Lin: --- tunnelDidOpen ---")
    }
    
    /// Handle the event of the tunnel connection being closed.
    func tunnelDidClose(_ targetTunnel: Tunnel) {
        os_log("BH_Lin: +++ tunnelDidClose +++")
        
        if pendingStartCompletion != nil {
            // Closed while starting, call the start completion handler with the appropriate error.
            pendingStartCompletion?(tunnel?.lastError)
            pendingStartCompletion = nil
        }
        else if pendingStopCompletion != nil {
            // Closed as the result of a call to stopTunnelWithReason, call the stop completion handler.
            pendingStopCompletion?()
            pendingStopCompletion = nil
        }
        else {
            // Closed as the result of an error on the tunnel connection, cancel the tunnel.
            cancelTunnelWithError(tunnel?.lastError)
        }
        tunnel = nil
        os_log("BH_Lin: --- tunnelDidClose ---")
    }
    
    /// Handle the server sending a configuration.
    func tunnelDidSendConfiguration(_ targetTunnel: Tunnel, configuration: [String : AnyObject]) {
        os_log("BH_Lin: +++ tunnelDidSendConfiguration +++")
    }
    
    // MARK: ClientTunnelConnectionDelegate
    
    /// Handle the event of the logical flow of packets being established through the tunnel.
    func tunnelConnectionDidOpen(_ connection: ClientTunnelConnection, configuration: [NSObject: AnyObject]) {
        os_log("BH_Lin: +++ tunnelConnectionDidOpen +++")
        
        // Create the virtual interface settings.
        guard let settings = createTunnelSettingsFromConfiguration(configuration) else {
            pendingStartCompletion?(SimpleTunnelError.internalError as NSError)
            pendingStartCompletion = nil
            return
        }
        
        // Set the virtual interface settings.
        setTunnelNetworkSettings(settings) { error in
            os_log("BH_Lin: +++ setTunnelNetworkSettings +++")
            
            var startError: NSError?
            if let error = error {
                simpleTunnelLog("Failed to set the tunnel network settings: \(error)")
                startError = SimpleTunnelError.badConfiguration as NSError
            }
            else {
                // Now we can start reading and writing packets to/from the virtual interface.
                self.tunnelConnection?.startHandlingPackets()
            }
            
            // Now the tunnel is fully established, call the start completion handler.
            self.pendingStartCompletion?(startError)
            self.pendingStartCompletion = nil
        }
    }
    
    /// Handle the event of the logical flow of packets being torn down.
    func tunnelConnectionDidClose(_ connection: ClientTunnelConnection, error: NSError?) {
        os_log("BH_Lin: +++ tunnelConnectionDidClose +++")
        tunnelConnection = nil
        tunnel?.closeTunnelWithError(error)
    }
    
    /// Create the tunnel network settings to be applied to the virtual interface.
    func createTunnelSettingsFromConfiguration(_ configuration: [NSObject: AnyObject]) ->
    NEPacketTunnelNetworkSettings? {
        
        os_log("BH_Lin: +++ createTunnelSettingsFromConfiguration +++")
        
        guard let tunnelAddress = tunnel?.remoteHost,
              let address = getValueFromPlist(configuration, keyArray: [.IPv4, .Address]) as? String,
              let netmask = getValueFromPlist(configuration, keyArray: [.IPv4, .Netmask]) as? String
        else { return nil }
        
        let newSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: tunnelAddress)
        var fullTunnel = true
        
        newSettings.ipv4Settings = NEIPv4Settings(addresses: [address], subnetMasks: [netmask])
        
        if let routes = getValueFromPlist(configuration, keyArray: [.IPv4, .Routes]) as? [[String: AnyObject]] {
            var includedRoutes = [NEIPv4Route]()
            for route in routes {
                if let netAddress = route[SettingsKey.Address.rawValue] as? String,
                   let netMask = route[SettingsKey.Netmask.rawValue] as? String
                {
                    includedRoutes.append(NEIPv4Route(destinationAddress: netAddress, subnetMask: netMask))
                }
            }
            newSettings.ipv4Settings?.includedRoutes = includedRoutes
            fullTunnel = false
        }
        else {
            // No routes specified, use the default route.
            newSettings.ipv4Settings?.includedRoutes = [NEIPv4Route.default()]
        }
        
        if let DNSDictionary = configuration[SettingsKey.DNS.rawValue as NSString] as? [String: AnyObject],
           let DNSServers = DNSDictionary[SettingsKey.Servers.rawValue] as? [String]
        {
            newSettings.dnsSettings = NEDNSSettings(servers: DNSServers)
            if let DNSSearchDomains = DNSDictionary[SettingsKey.SearchDomains.rawValue] as? [String] {
                newSettings.dnsSettings?.searchDomains = DNSSearchDomains
                if !fullTunnel {
                    newSettings.dnsSettings?.matchDomains = DNSSearchDomains
                }
            }
        }
        
        newSettings.tunnelOverheadBytes = 150
        
        os_log("BH_Lin: --- createTunnelSettingsFromConfiguration ---")
        
        return newSettings
    }
}
