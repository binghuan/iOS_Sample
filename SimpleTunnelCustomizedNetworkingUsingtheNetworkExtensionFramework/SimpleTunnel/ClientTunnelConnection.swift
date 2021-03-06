/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	This file contains the ClientTunnelConnection class. The ClientTunnelConnection class handles the encapsulation and decapsulation of IP packets in the client side of the SimpleTunnel tunneling protocol.
*/

import Foundation
import SimpleTunnelServices
import NetworkExtension
import os

// MARK: Protocols

/// The delegate protocol for ClientTunnelConnection.
protocol ClientTunnelConnectionDelegate {
	/// Handle the connection being opened.
	func tunnelConnectionDidOpen(_ connection: ClientTunnelConnection, configuration: [NSObject: AnyObject])
	/// Handle the connection being closed.
	func tunnelConnectionDidClose(_ connection: ClientTunnelConnection, error: NSError?)
}

/// An object used to tunnel IP packets using the SimpleTunnel protocol.
class ClientTunnelConnection: Connection {

	// MARK: Properties

	/// The connection delegate.
	let delegate: ClientTunnelConnectionDelegate

	/// The flow of IP packets.
	let packetFlow: NEPacketTunnelFlow

	// MARK: Initializers

	init(tunnel: ClientTunnel, clientPacketFlow: NEPacketTunnelFlow, connectionDelegate: ClientTunnelConnectionDelegate) {
        os_log("BH_Lin: ClientTunnelConnection - init")
		delegate = connectionDelegate
		packetFlow = clientPacketFlow
		let newConnectionIdentifier = arc4random()
		super.init(connectionIdentifier: Int(newConnectionIdentifier), parentTunnel: tunnel)
	}

	// MARK: Interface

	/// Open the connection by sending a "connection open" message to the tunnel server.
	func open() {
        os_log("BH_Lin: ClientTunnelConnection - open")
        
		guard let clientTunnel = tunnel as? ClientTunnel else {
            os_log("BH_Lin: guard let clientTunnel = tunnel as? ClientTunnel")
            return
        }

        os_log("BH_Lin: ClientTunnelConnection - open - checkpoint A")
		let properties = createMessagePropertiesForConnection(identifier, commandType: .open, extraProperties:[
				TunnelMessageKey.TunnelType.rawValue: TunnelLayer.ip.rawValue as AnyObject
			])
        
        os_log("BH_Lin: ClientTunnelConnection - open - checkpoint B")

		clientTunnel.sendMessage(properties) { error in
			if let error = error {
                os_log("BH_Lin: ClientTunnelConnection - open, error \(error)")
				self.delegate.tunnelConnectionDidClose(self, error: error)
			}
		}
        os_log("BH_Lin: ClientTunnelConnection - open - checkpoint C")
	}

	/// Handle packets coming from the packet flow.
	func handlePackets(_ packets: [Data], protocols: [NSNumber]) {
        os_log("BH_Lin: ClientTunnelConnection - handlePackets")
        
		guard let clientTunnel = tunnel as? ClientTunnel else { return }

		let properties = createMessagePropertiesForConnection(identifier, commandType: .packets, extraProperties:[
				TunnelMessageKey.Packets.rawValue: packets as AnyObject,
				TunnelMessageKey.Protocols.rawValue: protocols as AnyObject
			])

		clientTunnel.sendMessage(properties) { error in
            os_log("BH_Lin: clientTunnel.sendMessage\(properties, privacy: .public)")
			if let sendError = error {
                os_log("BH_Lin: !!!! clientTunnel.sendError\(sendError.debugDescription, privacy: .public)")
				self.delegate.tunnelConnectionDidClose(self, error: sendError)
				return
			}

			// Read more packets.
			self.packetFlow.readPackets { inPackets, inProtocols in
                os_log("BH_Lin: Read more packets.")
				self.handlePackets(inPackets, protocols: inProtocols)
			}
		}
	}

	/// Make the initial readPacketsWithCompletionHandler call.
	func startHandlingPackets() {
        os_log("BH_Lin: ClientTunnelConnection - startHandlingPackets")
        
		packetFlow.readPackets { inPackets, inProtocols in
            os_log("BH_Lin: packetFlow.readPackets")
			self.handlePackets(inPackets, protocols: inProtocols)
		}
	}

	// MARK: Connection

	/// Handle the event of the connection being established.
	override func handleOpenCompleted(_ resultCode: TunnelConnectionOpenResult, properties: [NSObject: AnyObject]) {
        os_log("BH_Lin: ClientTunnelConnection - handleOpenCompleted")
        
		guard resultCode == .success else {
			delegate.tunnelConnectionDidClose(self, error: SimpleTunnelError.badConnection as NSError)
			return
		}

		// Pass the tunnel network settings to the delegate.
		if let configuration = properties[TunnelMessageKey.Configuration.rawValue as NSString] as? [NSObject: AnyObject] {
			delegate.tunnelConnectionDidOpen(self, configuration: configuration)
		}
		else {
			delegate.tunnelConnectionDidOpen(self, configuration: [:])
		}
	}

	/// Send packets to the virtual interface to be injected into the IP stack.
	override func sendPackets(_ packets: [Data], protocols: [NSNumber]) {
        os_log("BH_Lin: ClientTunnelConnection - sendPackets")
        
		packetFlow.writePackets(packets, withProtocols: protocols)
	}
}
