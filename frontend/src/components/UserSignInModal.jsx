import { useEffect, useRef, useState } from 'react'
import { isOtpVerifyAccepted, otpFailureMessage } from '../utils/otpValidation'

const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:5000'
const OTP_LENGTH = 6
const RESEND_SECONDS = 60

function UserSignInModal({ onClose, onSignedIn, onCreateAccount }) {
  const [mode, setMode] = useState('password') // 'password' | 'otp'
  const [otpStep, setOtpStep] = useState('mobile') // 'mobile' | 'otp'
  const [mobile, setMobile] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [digits, setDigits] = useState(Array(OTP_LENGTH).fill(''))
  const [timer, setTimer] = useState(RESEND_SECONDS)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const inputRefs = useRef([])

  const cleanedMobile = mobile.replace(/\D/g, '').slice(0, 10)
  const isMobileValid = cleanedMobile.length === 10
  const otpComplete = digits.every((d) => d !== '')
  const canSubmitPassword = isMobileValid && password.length >= 6

  useEffect(() => {
    if (mode !== 'otp' || otpStep !== 'otp' || timer <= 0) return
    const id = setTimeout(() => setTimer((t) => t - 1), 1000)
    return () => clearTimeout(id)
  }, [mode, otpStep, timer])

  useEffect(() => {
    if (mode === 'otp' && otpStep === 'otp') {
      inputRefs.current[0]?.focus()
    }
  }, [mode, otpStep])

  function switchMode(nextMode) {
    setMode(nextMode)
    setError('')
    setOtpStep('mobile')
    setDigits(Array(OTP_LENGTH).fill(''))
    setPassword('')
  }

  async function loginWithPassword(event) {
    event.preventDefault()
    if (!canSubmitPassword || loading) return
    setLoading(true)
    setError('')
    try {
      const response = await fetch(`${API_BASE}/api/user/login/password`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ mobile: cleanedMobile, password }),
      })
      const contentType = response.headers.get('content-type') || ''
      if (!contentType.includes('application/json')) {
        setError(
          response.status === 404
            ? 'Password sign-in is not available on the server yet. Deploy the latest backend, or sign in with OTP.'
            : 'Could not reach the login service. Please try again.',
        )
        return
      }
      const data = await response.json()
      if (response.ok && data.success && data.data?.token) {
        onSignedIn({ token: data.data.token, user: data.data.user })
      } else {
        setError(data.message || 'Invalid mobile number or password.')
      }
    } catch {
      setError('Could not reach the server. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  async function sendOtp() {
    if (!isMobileValid || loading) return
    setLoading(true)
    setError('')
    try {
      const response = await fetch(`${API_BASE}/api/user/login/send-otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ mobile: cleanedMobile }),
      })
      const data = await response.json()
      if (response.ok && data.success) {
        setOtpStep('otp')
        setTimer(RESEND_SECONDS)
        setDigits(Array(OTP_LENGTH).fill(''))
      } else {
        setError(data.message || 'Failed to send OTP.')
      }
    } catch {
      setError('Could not reach the server. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  async function verifyOtp() {
    await verifyOtpWith(digits.join(''))
  }

  function handleDigitChange(index, value) {
    const char = value.replace(/\D/g, '').slice(-1)
    const updated = [...digits]
    updated[index] = char
    setDigits(updated)
    setError('')
    if (char && index < OTP_LENGTH - 1) {
      inputRefs.current[index + 1]?.focus()
    }
    if (updated.every((d) => d !== '')) {
      queueMicrotask(() => {
        const otp = updated.join('')
        if (otp.length === OTP_LENGTH) verifyOtpWith(otp)
      })
    }
  }

  async function verifyOtpWith(otp) {
    const cleaned = String(otp || '').replace(/\D/g, '')
    if (cleaned.length !== OTP_LENGTH || loading) return
    setLoading(true)
    setError('')
    try {
      const response = await fetch(`${API_BASE}/api/user/login/verify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ mobile: cleanedMobile, otp: cleaned }),
      })
      const data = await response.json()
      if (response.ok && isOtpVerifyAccepted(data) && data.data?.token) {
        onSignedIn({ token: data.data.token, user: data.data.user })
      } else {
        setError(otpFailureMessage(data))
        setDigits(Array(OTP_LENGTH).fill(''))
        inputRefs.current[0]?.focus()
      }
    } catch {
      setError('Could not reach the server. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  function handleKeyDown(index, event) {
    if (event.key === 'Backspace') {
      if (digits[index]) {
        const updated = [...digits]
        updated[index] = ''
        setDigits(updated)
      } else if (index > 0) {
        inputRefs.current[index - 1]?.focus()
      }
    }
  }

  function handlePaste(event) {
    event.preventDefault()
    const pasted = event.clipboardData.getData('text').replace(/\D/g, '').slice(0, OTP_LENGTH)
    const updated = Array(OTP_LENGTH).fill('')
    for (let i = 0; i < pasted.length; i++) updated[i] = pasted[i]
    setDigits(updated)
    const focusIdx = Math.min(pasted.length, OTP_LENGTH - 1)
    inputRefs.current[focusIdx]?.focus()
    if (pasted.length === OTP_LENGTH) {
      queueMicrotask(() => verifyOtpWith(pasted))
    }
  }

  const subtitle =
    mode === 'password'
      ? 'Sign in with your registered mobile number and password.'
      : otpStep === 'mobile'
        ? 'Enter the mobile number used for your loan application.'
        : `Enter the 6-digit OTP sent to +91 ${cleanedMobile}`

  return (
    <>
      <div className="fixed inset-0 z-50 bg-black/40" onClick={onClose} />
      <div className="fixed inset-x-0 bottom-0 z-50 mx-auto w-full max-w-lg rounded-t-3xl bg-white px-6 pb-10 pt-6 shadow-2xl sm:inset-y-auto sm:bottom-auto sm:top-1/2 sm:-translate-y-1/2 sm:rounded-3xl">
        <div className="mx-auto mb-5 h-1 w-10 rounded-full bg-slate-200 sm:hidden" />

        <div className="mb-1 flex items-start justify-between gap-3">
          <div>
            <h2 className="text-2xl font-bold text-slate-900">Sign In</h2>
            <p className="mt-1 text-sm text-slate-500">{subtitle}</p>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-slate-100 text-lg font-bold text-slate-600 hover:bg-slate-200"
            aria-label="Close"
          >
            ×
          </button>
        </div>

        <div className="mt-5 grid grid-cols-2 gap-2 rounded-2xl bg-slate-100 p-1">
          <button
            type="button"
            onClick={() => switchMode('password')}
            className={`rounded-xl py-2.5 text-sm font-semibold transition-colors ${
              mode === 'password'
                ? 'bg-white text-slate-900 shadow-sm'
                : 'text-slate-500 hover:text-slate-700'
            }`}
          >
            Phone & Password
          </button>
          <button
            type="button"
            onClick={() => switchMode('otp')}
            className={`rounded-xl py-2.5 text-sm font-semibold transition-colors ${
              mode === 'otp'
                ? 'bg-white text-slate-900 shadow-sm'
                : 'text-slate-500 hover:text-slate-700'
            }`}
          >
            OTP
          </button>
        </div>

        {mode === 'password' ? (
          <form className="mt-6" onSubmit={loginWithPassword}>
            <label className="block">
              <span className="mb-1.5 block text-sm font-medium text-slate-700">Mobile number</span>
              <div className="flex overflow-hidden rounded-xl border border-slate-300 focus-within:border-[var(--brand)]">
                <span className="flex items-center bg-slate-50 px-3 text-sm font-medium text-slate-600">
                  +91
                </span>
                <input
                  type="tel"
                  inputMode="numeric"
                  value={cleanedMobile}
                  onChange={(e) => {
                    setMobile(e.target.value)
                    setError('')
                  }}
                  placeholder="10-digit mobile number"
                  className="w-full px-3 py-3 text-sm text-slate-900 outline-none"
                  autoComplete="tel"
                  required
                />
              </div>
            </label>

            <label className="mt-4 block">
              <span className="mb-1.5 block text-sm font-medium text-slate-700">Password</span>
              <div className="flex overflow-hidden rounded-xl border border-slate-300 focus-within:border-[var(--brand)]">
                <input
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => {
                    setPassword(e.target.value)
                    setError('')
                  }}
                  placeholder="Enter your password"
                  className="w-full px-3 py-3 text-sm text-slate-900 outline-none"
                  autoComplete="current-password"
                  required
                  minLength={6}
                />
                <button
                  type="button"
                  onClick={() => setShowPassword((v) => !v)}
                  className="px-3 text-sm font-medium text-slate-500 hover:text-slate-700"
                >
                  {showPassword ? 'Hide' : 'Show'}
                </button>
              </div>
            </label>

            {error ? <p className="mt-3 text-sm text-red-500">{error}</p> : null}

            <button
              type="submit"
              disabled={!canSubmitPassword || loading}
              className="mt-6 w-full rounded-2xl bg-[var(--brand)] py-3.5 text-base font-semibold text-white hover:bg-[var(--brand-deep)] disabled:cursor-not-allowed disabled:bg-slate-300"
            >
              {loading ? 'Signing in...' : 'Sign In'}
            </button>
          </form>
        ) : otpStep === 'mobile' ? (
          <form
            className="mt-6"
            onSubmit={(event) => {
              event.preventDefault()
              sendOtp()
            }}
          >
            <label className="block">
              <span className="mb-1.5 block text-sm font-medium text-slate-700">Mobile number</span>
              <div className="flex overflow-hidden rounded-xl border border-slate-300 focus-within:border-[var(--brand)]">
                <span className="flex items-center bg-slate-50 px-3 text-sm font-medium text-slate-600">
                  +91
                </span>
                <input
                  type="tel"
                  inputMode="numeric"
                  value={cleanedMobile}
                  onChange={(e) => {
                    setMobile(e.target.value)
                    setError('')
                  }}
                  placeholder="10-digit mobile number"
                  className="w-full px-3 py-3 text-sm text-slate-900 outline-none"
                  autoComplete="tel"
                  required
                />
              </div>
            </label>

            {error ? <p className="mt-3 text-sm text-red-500">{error}</p> : null}

            <button
              type="submit"
              disabled={!isMobileValid || loading}
              className="mt-6 w-full rounded-2xl bg-[var(--brand)] py-3.5 text-base font-semibold text-white hover:bg-[var(--brand-deep)] disabled:cursor-not-allowed disabled:bg-slate-300"
            >
              {loading ? 'Sending OTP...' : 'Send OTP'}
            </button>
          </form>
        ) : (
          <div className="mt-6">
            <button
              type="button"
              onClick={() => {
                setOtpStep('mobile')
                setError('')
                setDigits(Array(OTP_LENGTH).fill(''))
              }}
              className="mb-4 text-sm font-medium text-[var(--brand)] hover:underline"
            >
              ← Change mobile number
            </button>

            <div className="flex justify-between gap-2" onPaste={handlePaste}>
              {digits.map((digit, index) => (
                <input
                  key={index}
                  ref={(el) => {
                    inputRefs.current[index] = el
                  }}
                  type="tel"
                  inputMode="numeric"
                  autoComplete={index === 0 ? 'one-time-code' : 'off'}
                  maxLength={1}
                  value={digit}
                  onChange={(e) => handleDigitChange(index, e.target.value)}
                  onKeyDown={(e) => handleKeyDown(index, e)}
                  aria-label={`OTP digit ${index + 1}`}
                  className={`h-14 w-full rounded-2xl border-2 text-center text-xl font-semibold text-slate-900 outline-none transition-colors ${
                    digit
                      ? 'border-[var(--brand)] bg-white'
                      : 'border-slate-200 bg-slate-100'
                  } focus:border-blue-500 focus:bg-white`}
                />
              ))}
            </div>

            {error ? <p className="mt-3 text-sm text-red-500">{error}</p> : null}

            <div className="mt-5 text-center">
              <p className="text-sm text-slate-500">Have not received your OTP?</p>
              {timer > 0 ? (
                <p className="mt-1 text-sm font-semibold text-green-600">Resend in {timer} seconds</p>
              ) : (
                <button
                  type="button"
                  onClick={sendOtp}
                  disabled={loading}
                  className="mt-1 text-sm font-semibold text-[var(--brand)] disabled:opacity-50"
                >
                  {loading ? 'Resending...' : 'Resend OTP'}
                </button>
              )}
            </div>

            <button
              type="button"
              disabled={!otpComplete || loading}
              onClick={verifyOtp}
              className="mt-6 w-full rounded-2xl bg-[var(--brand)] py-3.5 text-base font-semibold text-white hover:bg-[var(--brand-deep)] disabled:cursor-not-allowed disabled:bg-slate-300"
            >
              {loading ? 'Signing in...' : 'Sign In'}
            </button>
          </div>
        )}

        {onCreateAccount ? (
          <p className="mt-5 text-center text-sm text-slate-500">
            New here?{' '}
            <button
              type="button"
              onClick={onCreateAccount}
              className="font-semibold text-[var(--navy)] hover:underline"
            >
              Create an account
            </button>
          </p>
        ) : null}
      </div>
    </>
  )
}

export default UserSignInModal
