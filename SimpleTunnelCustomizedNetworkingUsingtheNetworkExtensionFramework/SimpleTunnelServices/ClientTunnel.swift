/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 This file contains the ClientTunnel class. The ClientTunnel class implements the client side of the SimpleTunnel tunneling protocol.
 */

import Foundation
import NetworkExtension
import os

/// Make NEVPNStatus convertible to a string
extension NWTCPConnectionState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .cancelled: return "Cancelled"
        case .connected: return "Connected"
        case .connecting: return "Connecting"
        case .disconnected: return "Disconnected"
        case .invalid: return "Invalid"
        case .waiting: return "Waiting"
        }
    }
}

/// The client-side implementation of the SimpleTunnel protocol.
open class ClientTunnel: Tunnel {
    
    // MARK: Properties
    
    /// The tunnel connection.
    open var connection: NWTCPConnection?
    
    /// The last error that occurred on the tunnel.
    open var lastError: NSError?
    
    /// The previously-received incomplete message data.
    var previousData: NSMutableData?
    
    /// The address of the tunnel server.
    open var remoteHost: String?
    
    // MARK: Interface
    
    /// Start the TCP connection to the tunnel server.
    open func startTunnel(_ provider: NETunnelProvider) -> SimpleTunnelError? {
        
        os_log("BH_Lin: ClientTunnel >> startTunnel")
        
        guard let serverAddress = provider.protocolConfiguration.serverAddress else {
            os_log("BH_Lin: ClientTunnel badConfiguration")
            return .badConfiguration
        }
        
        var endpoint: NWEndpoint
        
        if let colonRange = serverAddress.rangeOfCharacter(from: CharacterSet(charactersIn: ":"), options: [], range: nil) {
            
            // The server is specified in the configuration as <host>:<port>.
            os_log("BH_Lin: The server is specified in the configuration as <host>:<port>. \(serverAddress, privacy: .public)")
            let hostname = serverAddress.substring(with: serverAddress.startIndex..<colonRange.lowerBound)
            let portString = serverAddress.substring(with: serverAddress.index(after: colonRange.lowerBound)..<serverAddress.endIndex)
            os_log("BH_Lin: hostname \(hostname , privacy: .public))")
            os_log("BH_Lin: portString \(portString , privacy: .public))")
            
            guard !hostname.isEmpty && !portString.isEmpty else {
                os_log("BH_Lin: ClientTunnel colonRange badConfiguration")
                return .badConfiguration
            }
            
            endpoint = NWHostEndpoint(hostname:hostname, port:portString)
            os_log("BH_Lin: NWHostEndpoint(hostname:\(hostname, privacy: .public), port:\(portString,privacy: .public)")
        }
        else {
            // The server is specified in the configuration as a Bonjour service name.
            os_log("BH_Lin: The server is specified in the configuration as a Bonjour service name.")
            endpoint = NWBonjourServiceEndpoint(name: serverAddress, type:Tunnel.serviceType, domain:Tunnel.serviceDomain)
        }
        
        // Kick off the connection to the server.
        os_log("BH_Lin: Kick off the connection to the server.")
        connection = provider.createTCPConnection(to: endpoint, enableTLS:false, tlsParameters:nil, delegate:nil)
        
        guard var tcpConnection = connection else {
            os_log("BH_Lin: Fail - createTCPConnection")
            return nil
        }
        
        // Register for notificationes when the connection status changes.
        os_log("BH_Lin: [START] Register for notificationes when the connection status changes.")
        tcpConnection.addObserver(self, forKeyPath: "state", options: .initial, context: &tcpConnection)
        connection = tcpConnection
        os_log("BH_Lin: [DONE ] Register for notificationes when the connection status changes.")
        
        return nil
    }
    
    /// Close the tunnel.
    open func closeTunnelWithError(_ error: NSError?) {
        os_log("BH_Lin: closeTunnelWithError")
        lastError = error
        closeTunnel()
    }
    
    /// Read a SimpleTunnel packet from the tunnel connection.
    func readNextPacket() {
        os_log("BH_Lin: readNextPacket")
        guard let targetConnection = connection else {
            os_log("BH_Lin: closeTunnelWithError")
            closeTunnelWithError(SimpleTunnelError.badConnection as NSError)
            return
        }
        
        // First, read the total length of the packet.
        os_log("BH_Lin: First, read the total length of the packet.")
        targetConnection.readMinimumLength(MemoryLayout<UInt32>.size, maximumLength: MemoryLayout<UInt32>.size) { data, error in
            if let readError = error {
                os_log("BH_Lin: Got an error on the tunnel connection")
                simpleTunnelLog("Got an error on the tunnel connection: \(readError)")
                self.closeTunnelWithError(readError as NSError?)
                return
            }
            
            let lengthData = data
            
            guard lengthData!.count == MemoryLayout<UInt32>.size else {
                os_log("BH_Lin: Length data length (\(lengthData!.count)) != sizeof(UInt32) (\(MemoryLayout<UInt32>.size)")
                simpleTunnelLog("Length data length (\(lengthData!.count)) != sizeof(UInt32) (\(MemoryLayout<UInt32>.size)")
                self.closeTunnelWithError(SimpleTunnelError.internalError as NSError)
                return
            }
            
            var totalLength: UInt32 = 0
            (lengthData! as NSData).getBytes(&totalLength, length: MemoryLayout<UInt32>.size)
            
            if totalLength > UInt32(Tunnel.maximumMessageSize) {
                simpleTunnelLog("Got a length that is too big: \(totalLength)")
                os_log("BH_Lin: Got a length that is too big: \(totalLength)")
                self.closeTunnelWithError(SimpleTunnelError.internalError as NSError)
                return
            }
            
            totalLength -= UInt32(MemoryLayout<UInt32>.size)
            
            // Second, read the packet payload.
            os_log("BH_Lin: Second, read the packet payload.")
            targetConnection.readMinimumLength(Int(totalLength), maximumLength: Int(totalLength)) { data, error in
                if let payloadReadError = error {
                    os_log("BH_Lin: Got a length that is too big: \(totalLength)")
                    simpleTunnelLog("Got an error on the tunnel connection: \(payloadReadError)")
                    self.closeTunnelWithError(payloadReadError as NSError?)
                    return
                }
                
                let payloadData = data
                
                guard payloadData!.count == Int(totalLength) else {
                    os_log("BH_Lin: Payload data length (\(payloadData!.count)) != payload length (\(totalLength)")
                    simpleTunnelLog("Payload data length (\(payloadData!.count)) != payload length (\(totalLength)")
                    self.closeTunnelWithError(SimpleTunnelError.internalError as NSError)
                    return
                }
                
                os_log("BH_Lin: --> handlePacket")
                _ = self.handlePacket(payloadData!)
                
                os_log("BH_Lin: --> readNextPacket")
                self.readNextPacket()
            }
        }
    }
    
    /// Send a message to the tunnel server.
    open func sendMessage(_ messageProperties: [String: AnyObject], completionHandler: @escaping (NSError?) -> Void) {
        os_log("BH_Lin: +++ sendMessage")
        guard let messageData = serializeMessage(messageProperties) else {
            os_log("BH_Lin: sendMessage - SimpleTunnelError.internalError")
            completionHandler(SimpleTunnelError.internalError as NSError)
            return
        }
        
        os_log("BH_Lin: sendMessage - connection?.write: isEmpty = \(messageData.isEmpty) , data = \(messageData, privacy: .public)")
        connection?.write(messageData, completionHandler: {error -> Void in
            if(error.debugDescription != "nil") {
                os_log("BH_Lin: NG> sendMessage - connection?.write: \(error.debugDescription, privacy: .public)")
            }
        })
        os_log("BH_Lin: --- sendMessage")
    }
    
    // MARK: NSObject
    
    /// Handle changes to the tunnel connection state.
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        
        simpleTunnelLog("+++ observeValue forKeyPath \(String(describing: keyPath))")
        
        guard keyPath == "state"
        //&& context?.assumingMemoryBound(to: Optional<NWTCPConnection>.self).pointee == connection
        else {
            simpleTunnelLog("!!!! bypass forKeyPath \(String(describing: keyPath))")
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        simpleTunnelLog("--- observeValue forKeyPath \(String(describing: keyPath))")
        
        simpleTunnelLog("Tunnel connection state changed to \(connection!.state), \(String(describing: connection?.endpoint))")
        
        switch connection!.state {
        case .connected:
            if let remoteAddress = self.connection!.remoteAddress as? NWHostEndpoint {
                remoteHost = remoteAddress.hostname
            }
            
            // Start reading messages from the tunnel connection.
            readNextPacket()
            
            // Let the delegate know that the tunnel is open
            delegate?.tunnelDidOpen(self)
            
        case .disconnected:
            os_log("BH_Lin: closeTunnelWithError")
            closeTunnelWithError(connection!.error as NSError?)
            
        case .cancelled:
            os_log("BH_Lin: [START] removeObserver")
            //connection?.removeObserver(self, forKeyPath:"state", context: &connection)
            connection?.removeObserver(self, forKeyPath:"state")
            os_log("BH_Lin: [END] removeObserver")
            connection = nil
            delegate?.tunnelDidClose(self)
            
        default:
            break
        }
    }
    
    
    // MARK: Tunnel
    
    /// Close the tunnel.
    override open func closeTunnel() {
        os_log("BH_Lin: closeTunnel")
        
        super.closeTunnel()
        // Close the tunnel connection.
        if let TCPConnection = connection {
            TCPConnection.cancel()
        }
        
    }
    
    /// Write data to the tunnel connection.
    override func writeDataToTunnel(_ data: Data, startingAtOffset: Int) -> Int {
        os_log("BH_Lin: writeDataToTunnel")
        connection?.write(data) { error in
            if error != nil {
                self.closeTunnelWithError(error as NSError?)
            }
        }
        return data.count
    }
    
    /// Handle a message received from the tunnel server.
    override func handleMessage(_ commandType: TunnelCommand, properties: [String: AnyObject], connection: Connection?) -> Bool {
        
        os_log("BH_Lin: handleMessage \(properties.description, privacy: .public)")
        
        var success = true
        
        switch commandType {
        case .openResult:
            // A logical connection was opened successfully.
            os_log("BH_Lin: A logical connection was opened successfully.")
            guard let targetConnection = connection,
                  let resultCodeNumber = properties[TunnelMessageKey.ResultCode.rawValue] as? Int,
                  let resultCode = TunnelConnectionOpenResult(rawValue: resultCodeNumber)
            else
            {
                success = false
                break
            }
            
            targetConnection.handleOpenCompleted(resultCode, properties:properties as [NSObject : AnyObject])
            
        case .fetchConfiguration:
            os_log("BH_Lin: fetchConfiguration")
            guard let configuration = properties[TunnelMessageKey.Configuration.rawValue] as? [String: AnyObject]
            else { break }
            
            delegate?.tunnelDidSendConfiguration(self, configuration: configuration)
            
        default:
            simpleTunnelLog("Tunnel received an invalid command")
            success = false
        }
        return success
    }
    
    /// Send a FetchConfiguration message on the tunnel connection.
    open func sendFetchConfiguation() {
        os_log("BH_Lin: sendFetchConfiguation")
        
        let properties = createMessagePropertiesForConnection(0, commandType: .fetchConfiguration)
        if !sendMessage(properties) {
            simpleTunnelLog("Failed to send a fetch configuration message")
        }
    }
}
