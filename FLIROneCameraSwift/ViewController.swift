//
//  ViewController.swift
//  FLIROneCameraSwift
//
//  Created by FLIR on 2020-08-13.
//  Copyright © 2020 FLIR Systems AB. All rights reserved.
//

import UIKit
import AVFoundation
import ThermalSDK

class ViewController: UIViewController {
    var discovery: FLIRDiscovery?
    var camera: FLIRCamera?
    var ironPalette: Bool = true

    @IBOutlet weak var centerSpotLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var distanceSlider: UISlider!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var scaleImageView: UIImageView!

    @IBOutlet weak var latencySegmentedControl: UISegmentedControl!
    @IBOutlet weak var upscaleSegmentedControl: UISegmentedControl!
    @IBOutlet weak var useDenoiseSwitch: UISwitch!
    
    var thermalStreamer: FLIRThermalStreamer?
    var stream: FLIRStream?

    let renderQueue = DispatchQueue(label: "render")

    // Set this to the LAN IP of the machine running Unity.
    // On the FLIR hotspot, devices get link-local 169.254.x.x addresses.
    let udpSender = UDPSender(host: "169.254.220.80", port: 9000)

    let roiLayer: CAShapeLayer = {
        let l = CAShapeLayer()
        l.strokeColor = UIColor.systemYellow.cgColor
        l.fillColor = UIColor.clear.cgColor
        l.lineWidth = 2
        l.lineDashPattern = [6, 4]
        return l
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        discovery = FLIRDiscovery()
        discovery?.delegate = self
        imageView.layer.addSublayer(roiLayer)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateROILayer()
    }

    func updateROILayer() {
        let bounds = imageView.bounds
        let imageSize = imageView.image?.size ?? CGSize(width: 4, height: 3)
        let displayRect = AVMakeRect(aspectRatio: imageSize, insideRect: bounds)
        let w = displayRect.width * 0.30
        let h = displayRect.height * 0.20
        let roi = CGRect(x: displayRect.midX - w / 2,
                         y: displayRect.midY - h / 2,
                         width: w,
                         height: h)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        roiLayer.frame = bounds
        roiLayer.path = UIBezierPath(rect: roi).cgPath
        CATransaction.commit()
    }

    func requireCamera() {
        guard camera == nil else {
            return
        }
        let camera = FLIRCamera()
        self.camera = camera
        camera.delegate = self
    }

    @IBAction func connectDeviceClicked(_ sender: Any) {
        // discover F1 classic (on lightning interface) and F1 Edge (on BLE)
        discovery?.start([.lightning, .flirOneWireless])
    }

    @IBAction func disconnectClicked(_ sender: Any) {
        camera?.disconnect()
    }

    @IBAction func connectEmulatorClicked(_ sender: Any) {
        discovery?.start(.emulator)
    }

    @IBAction func ironPaletteClicked(_ sender: Any) {
        ironPalette = !ironPalette
    }

    @IBAction func distanceSliderValueChanged(_ sender: Any) {
        if let remoteControl = self.camera?.getRemoteControl(),
           let fusionController = remoteControl.getFusionController() {
            let newDistance = distanceSlider.value
            try? fusionController.setFusionDistance(Double(newDistance))
        }
    }

    @IBAction func latencySegmentedControlValueChanged(_ sender: Any) {
        guard let value = FLIRVividIRLatency(rawValue: latencySegmentedControl.selectedSegmentIndex) else { return }
        thermalStreamer?.vividIRParameters?.latency = value
    }

    @IBAction func upscaleSegmentedControlValueChanged(_ sender: Any) {
        guard let value = FLIRVividIRUpscale(rawValue: upscaleSegmentedControl.selectedSegmentIndex) else { return }
        thermalStreamer?.vividIRParameters?.upscale = value
    }
    
    @IBAction func useDenoiseSwitchValueChanged(_ sender: Any) {
        thermalStreamer?.vividIRParameters?.useDenoise = useDenoiseSwitch.isOn
    }
}

extension ViewController: FLIRDiscoveryEventDelegate {

    func cameraDiscovered(_ discoveredCamera: FLIRDiscoveredCamera) {
        let cameraIdentity = discoveredCamera.identity
        switch cameraIdentity.cameraType() {
        case .flirOne, .flirEdge, .flirEdgePro:
            NSLog("type \(cameraIdentity.cameraType())  dn \(discoveredCamera.displayName)")
            requireCamera()
            guard !camera!.isConnected() else {
                return
            }
            DispatchQueue.global().async {
                do {
                    try self.camera?.pair(cameraIdentity, code: 0)
                    try self.camera?.connect()
                    let streams = self.camera?.getStreams()
                    guard let stream = streams?.first else {
                        NSLog("No streams found on camera!")
                        return
                    }
                    if let information: FLIRCameraInformation = try? self.camera?.getRemoteControl()?.getCameraInformation() {
                        NSLog("information \(information)")
                    }
                    self.stream = stream
                    let thermalStreamer = FLIRThermalStreamer(stream: stream)
                    self.thermalStreamer = thermalStreamer
                    thermalStreamer.autoScale = true
                    thermalStreamer.renderScale = true
                    stream.delegate = self
                    do {
                        try stream.start()
                    } catch {
                        NSLog("stream.start error \(error)")
                    }
                } catch {
                    NSLog("Camera connect error \(error)")
                }
            }
        case .generic:
            ()
        default:
            fatalError("unknown cameraType")
        }
    }

    func discoveryError(_ error: String, netServiceError nsnetserviceserror: Int32, on iface: FLIRCommunicationInterface) {
        NSLog("\(#function)")
    }

    func discoveryFinished(_ iface: FLIRCommunicationInterface) {
        NSLog("\(#function)")
    }

    func cameraLost(_ cameraIdentity: FLIRIdentity) {
        NSLog("\(#function)")
    }
}

extension ViewController : FLIRDataReceivedDelegate {
    func onDisconnected(_ camera: FLIRCamera, withError error: Error?) {
        NSLog("\(#function) \(String(describing: error))")
        DispatchQueue.main.async {
            self.thermalStreamer = nil
            self.stream = nil
            let alert = UIAlertController(title: "Disconnected",
                                          message: "Flir One disconnected",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
}

extension ViewController : FLIRStreamDelegate {
    func onError(_ error: Error) {
        NSLog("\(#function) \(error)")
    }

    func onImageReceived() {
        renderQueue.async {
            guard let thermalStreamer = self.thermalStreamer else { return }
            do {
                try thermalStreamer.update()
            } catch {
                NSLog("update error \(error)")
            }
            let image = thermalStreamer.getImage()
            let vividIR = thermalStreamer.vividIRParameters
            DispatchQueue.main.async {
                self.imageView.image = image
                self.updateROILayer()
                if let scaleImage = thermalStreamer.getScaleImage() {
                    self.scaleImageView.image = scaleImage.resizableImage(withCapInsets: .zero, resizingMode: .stretch)
                }
                if let vividIR = vividIR {
                    self.latencySegmentedControl.selectedSegmentIndex = vividIR.latency.rawValue
                    self.upscaleSegmentedControl.selectedSegmentIndex = vividIR.upscale.rawValue
                    self.useDenoiseSwitch.isOn = vividIR.useDenoise
                }
                thermalStreamer.withThermalImage { image in
                    image.setTemperatureUnit(.CELSIUS)
                    if image.palette?.name == image.paletteManager?.iron.name {
                        if !self.ironPalette {
                            image.palette = image.paletteManager?.gray
                        }
                    } else {
                        if self.ironPalette {
                            image.palette = image.paletteManager?.iron
                        }
                    }
                    if let measurements = image.measurements {
                        if measurements.getAllRectangles().isEmpty {
                            do {
                                let w = CGFloat(image.getWidth())
                                let h = CGFloat(image.getHeight())
                                let rectW = w * 0.30
                                let rectH = h * 0.20
                                let roi = CGRect(x: (w - rectW) / 2,
                                                 y: (h - rectH) / 2,
                                                 width: rectW,
                                                 height: rectH)
                                let rect = try measurements.addRectangle(roi)
                                rect.isAverageEnabled = true
                                rect.isHotSpotEnabled = true
                                rect.isColdSpotEnabled = true
                            } catch {
                                NSLog("addRectangle error \(error)")
                            }
                        }
                        if let rect = measurements.getAllRectangles().first {
                            let avgC = rect.average.asCelsius().value
                            let minC = rect.min.asCelsius().value
                            let maxC = rect.max.asCelsius().value
                            self.centerSpotLabel.text = String(format: "avg %.2f   min %.2f   max %.2f °C", avgC, minC, maxC)
                            self.udpSender.send(avg: avgC, min: minC, max: maxC)
                        }
                    }
                    if let remoteControl = self.camera?.getRemoteControl(),
                       let fusionController = remoteControl.getFusionController() {
                        let distance = fusionController.getFusionDistance()
                        self.distanceLabel.text = "\((distance * 1000).rounded() / 1000)"
                        self.distanceSlider.value = Float(distance)
                    }
                }
            }
        }
    }
}
