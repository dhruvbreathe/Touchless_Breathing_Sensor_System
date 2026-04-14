using UnityEngine;
using UnityEngine.UI;

/// Reads the latest `max` temperature from a ThermalUdpReceiver, classifies
/// the breathing phase, and writes it to a UI Text on a Canvas.
///
/// Setup:
///   1. Hierarchy → UI → Canvas (creates Canvas + EventSystem if missing)
///   2. Right-click Canvas → UI → Text — Legacy. Stretch + center it, big font.
///   3. Drop this script on the Text GameObject (or any GameObject in the scene).
///   4. In the Inspector, drag the ThermalReceiver into `Receiver` and the Text into `Label`.
public class BreathingPhaseDisplay : MonoBehaviour
{
    public enum Phase { Calibrating, Inhaling, Holding, Exhaling }

    [Header("Inputs")]
    public ThermalUdpReceiver receiver;
    public Text label;

    [Header("Detection")]
    [Tooltip("Time constant (s) for smoothing the input signal before differentiating.")]
    public float smoothingTau = 0.3f;
    [Tooltip("Time constant (s) for smoothing the derivative itself (extra denoise).")]
    public float derivativeTau = 0.4f;
    [Tooltip("°C per second above which we call it exhaling (temp rising).")]
    public float exhaleRate = 0.25f;
    [Tooltip("°C per second below which we call it inhaling (temp falling, negative).")]
    public float inhaleRate = -0.25f;
    [Tooltip("Seconds to gather data before reporting any phase.")]
    public float warmupSeconds = 2f;

    [Header("Live values (read-only)")]
    public Phase phase = Phase.Calibrating;
    public float current;
    public float ratePerSecond;

    private bool seeded;
    private float previousCurrent;
    private float startTime;

    void Start()
    {
        if (receiver == null) receiver = FindObjectOfType<ThermalUdpReceiver>();
        startTime = Time.time;
    }

    void Update()
    {
        if (receiver == null || !receiver.connected) return;

        float v = receiver.max;
        float dt = Mathf.Max(Time.deltaTime, 1e-4f);

        if (!seeded)
        {
            current = v;
            previousCurrent = v;
            ratePerSecond = 0f;
            seeded = true;
        }
        else
        {
            // Smooth the input signal.
            current += (v - current) * Mathf.Clamp01(dt / smoothingTau);
            // Instantaneous rate of change in °C per second.
            float instRate = (current - previousCurrent) / dt;
            previousCurrent = current;
            // Smooth the rate too.
            ratePerSecond += (instRate - ratePerSecond) * Mathf.Clamp01(dt / derivativeTau);
        }

        if (Time.time - startTime < warmupSeconds)
        {
            phase = Phase.Calibrating;
        }
        else
        {
            // Hysteresis: once in a state, require the rate to drop past half the threshold to leave.
            switch (phase)
            {
                case Phase.Calibrating:
                case Phase.Holding:
                    if (ratePerSecond >= exhaleRate) phase = Phase.Exhaling;
                    else if (ratePerSecond <= inhaleRate) phase = Phase.Inhaling;
                    else phase = Phase.Holding;
                    break;
                case Phase.Exhaling:
                    if (ratePerSecond < exhaleRate * 0.5f) phase = Phase.Holding;
                    break;
                case Phase.Inhaling:
                    if (ratePerSecond > inhaleRate * 0.5f) phase = Phase.Holding;
                    break;
            }
        }

        if (label != null)
        {
            label.text = phase.ToString().ToUpper();
            switch (phase)
            {
                case Phase.Exhaling:    label.color = new Color(1f,   0.55f, 0.2f); break;
                case Phase.Inhaling:    label.color = new Color(0.3f, 0.7f,  1f);   break;
                case Phase.Holding:     label.color = Color.white;                  break;
                case Phase.Calibrating: label.color = new Color(0.6f, 0.6f, 0.6f);  break;
            }
        }
    }
}
