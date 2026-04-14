using System;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using UnityEngine;

/// Receives temperature packets from the FLIR ONE Edge Pro iOS app over UDP.
/// Attach this script to any GameObject in your scene.
/// Expected payload: {"t":<unix_seconds>,"avg":<c>,"min":<c>,"max":<c>}
public class ThermalUdpReceiver : MonoBehaviour
{
    [Tooltip("UDP port the iOS app sends to. Must match UDPSender in ViewController.swift.")]
    public int port = 9000;

    [Header("Live values (read-only)")]
    public double timestamp;
    public float avg;
    public float min;
    public float max;
    public bool connected;

    private UdpClient client;
    private Thread receiveThread;
    private volatile bool running;

    void Start()
    {
        client = new UdpClient(port);
        running = true;
        receiveThread = new Thread(ReceiveLoop) { IsBackground = true };
        receiveThread.Start();
        Debug.Log($"[ThermalUdpReceiver] Listening on UDP port {port}");
    }

    void OnDestroy()
    {
        running = false;
        client?.Close();
        receiveThread?.Join(500);
    }

    private void ReceiveLoop()
    {
        var endpoint = new IPEndPoint(IPAddress.Any, 0);
        while (running)
        {
            try
            {
                var data = client.Receive(ref endpoint);
                var json = Encoding.UTF8.GetString(data);
                var sample = JsonUtility.FromJson<Sample>(json);
                timestamp = sample.t;
                avg = sample.avg;
                min = sample.min;
                max = sample.max;
                connected = true;
            }
            catch (SocketException) { /* shutdown */ }
            catch (Exception e) { Debug.LogWarning($"[ThermalUdpReceiver] {e.Message}"); }
        }
    }

    void Update()
    {
        // Use the live values here, e.g. drive a UI, animate a character, etc.
        // Example: log once per second
        if (connected && Time.frameCount % 30 == 0)
        {
            Debug.Log($"avg={avg:F2}  min={min:F2}  max={max:F2}  t={timestamp:F2}");
        }
    }

    [Serializable]
    private class Sample
    {
        public double t;
        public float avg;
        public float min;
        public float max;
    }
}
