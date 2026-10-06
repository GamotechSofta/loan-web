import { useState } from 'react'

const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:5000'

function SignUpPage({ userProfile, onSignIn, onSignedUp, onViewProfile }) {
  const [fullName, setFullName] = useState('')
  const [mobile, setMobile] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const cleanedMobile = mobile.replace(/\D/g, '').slice(0, 10)
  const canSubmit =
    fullName.trim().length >= 2 &&
    cleanedMobile.length === 10 &&
    email.includes('@') &&
    password.length >= 6 &&
    password === confirmPassword

  async function handleSubmit(event) {
    event.preventDefault()
    if (loading) return
    if (password !== confirmPassword) {
      setError('Passwords do not match.')
      return
    }
    if (!canSubmit) return

    setLoading(true)
    setError('')
    try {
      const response = await fetch(`${API_BASE}/api/user/signup`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          fullName: fullName.trim(),
          mobile: cleanedMobile,
          email: email.trim(),
          password,
        }),
      })
      const contentType = response.headers.get('content-type') || ''
      if (!contentType.includes('application/json')) {
        setError('Could not reach the sign-up service. Please try again.')
        return
      }
      const data = await response.json()
      if (response.ok && data.success && data.data?.token) {
        onSignedUp?.({ token: data.data.token, user: data.data.user })
      } else {
        setError(data.message || 'Could not create your account.')
      }
    } catch {
      setError('Could not reach the server. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  if (userProfile) {
    return (
      <section className="px-4 py-16 sm:px-6 lg:px-8">
        <div className="mx-auto max-w-lg rounded-2xl border border-[var(--line)] bg-white p-6 shadow-sm sm:p-8">
          <h1 className="text-2xl font-bold text-[var(--navy)]">You are already signed in</h1>
          <p className="mt-2 text-sm text-slate-600">
            {userProfile.fullName || 'Your account'} is active on this device.
          </p>
          <button
            type="button"
            onClick={onViewProfile}
            className="mt-6 rounded-2xl bg-[var(--navy)] px-5 py-3 text-sm font-semibold text-white hover:bg-black"
          >
            Go to my profile
          </button>
        </div>
      </section>
    )
  }

  return (
    <>
      <section className="brand-hero-bg px-4 py-14 text-white sm:px-6 lg:px-8 lg:py-16">
        <div className="mx-auto max-w-6xl">
          <div className="mb-5 inline-flex rounded-2xl bg-white px-4 py-2">
            <p className="text-sm font-bold text-[var(--navy)]">Account</p>
          </div>
          <h1 className="max-w-3xl text-4xl font-bold leading-tight sm:text-5xl">Create your account</h1>
          <p className="mt-4 max-w-2xl text-base leading-relaxed text-white/90 sm:text-lg">
            Sign up with your mobile number to check your CIBIL score and apply for a loan.
          </p>
        </div>
      </section>

      <section className="px-4 py-12 sm:px-6 lg:px-8">
        <form
          onSubmit={handleSubmit}
          className="mx-auto max-w-lg rounded-2xl border border-[var(--line)] bg-white p-6 shadow-sm sm:p-8"
        >
          <label className="block">
            <span className="mb-1.5 block text-sm font-medium text-slate-700">Full name</span>
            <input
              type="text"
              value={fullName}
              onChange={(event) => {
                setFullName(event.target.value)
                setError('')
              }}
              placeholder="Your full name"
              autoComplete="name"
              required
              className="w-full rounded-xl border border-slate-300 px-3 py-3 text-sm text-slate-900 outline-none focus:border-[var(--navy)]"
            />
          </label>

          <label className="mt-4 block">
            <span className="mb-1.5 block text-sm font-medium text-slate-700">Mobile number</span>
            <div className="flex overflow-hidden rounded-xl border border-slate-300 focus-within:border-[var(--navy)]">
              <span className="flex items-center bg-slate-50 px-3 text-sm font-medium text-slate-600">+91</span>
              <input
                type="tel"
                inputMode="numeric"
                value={cleanedMobile}
                onChange={(event) => {
                  setMobile(event.target.value)
                  setError('')
                }}
                placeholder="10-digit mobile number"
                autoComplete="tel"
                required
                className="w-full px-3 py-3 text-sm text-slate-900 outline-none"
              />
            </div>
          </label>

          <label className="mt-4 block">
            <span className="mb-1.5 block text-sm font-medium text-slate-700">Email</span>
            <input
              type="email"
              value={email}
              onChange={(event) => {
                setEmail(event.target.value)
                setError('')
              }}
              placeholder="you@email.com"
              autoComplete="email"
              required
              className="w-full rounded-xl border border-slate-300 px-3 py-3 text-sm text-slate-900 outline-none focus:border-[var(--navy)]"
            />
          </label>

          <label className="mt-4 block">
            <span className="mb-1.5 block text-sm font-medium text-slate-700">Password</span>
            <div className="flex overflow-hidden rounded-xl border border-slate-300 focus-within:border-[var(--navy)]">
              <input
                type={showPassword ? 'text' : 'password'}
                value={password}
                onChange={(event) => {
                  setPassword(event.target.value)
                  setError('')
                }}
                placeholder="At least 6 characters"
                autoComplete="new-password"
                required
                minLength={6}
                className="w-full px-3 py-3 text-sm text-slate-900 outline-none"
              />
              <button
                type="button"
                onClick={() => setShowPassword((open) => !open)}
                className="px-3 text-xs font-semibold text-[var(--navy)]"
              >
                {showPassword ? 'Hide' : 'Show'}
              </button>
            </div>
          </label>

          <label className="mt-4 block">
            <span className="mb-1.5 block text-sm font-medium text-slate-700">Confirm password</span>
            <input
              type={showPassword ? 'text' : 'password'}
              value={confirmPassword}
              onChange={(event) => {
                setConfirmPassword(event.target.value)
                setError('')
              }}
              placeholder="Re-enter your password"
              autoComplete="new-password"
              required
              minLength={6}
              className="w-full rounded-xl border border-slate-300 px-3 py-3 text-sm text-slate-900 outline-none focus:border-[var(--navy)]"
            />
          </label>

          {error ? <p className="mt-4 text-sm text-rose-600">{error}</p> : null}

          <button
            type="submit"
            disabled={!canSubmit || loading}
            className="mt-6 w-full rounded-2xl bg-[var(--gold)] px-4 py-3 text-sm font-semibold text-white hover:bg-[#9a7234] disabled:cursor-not-allowed disabled:opacity-60"
          >
            {loading ? 'Creating account…' : 'Create account'}
          </button>

          <p className="mt-5 text-center text-sm text-slate-500">
            Already have an account?{' '}
            <button
              type="button"
              onClick={onSignIn}
              className="font-semibold text-[var(--navy)] hover:underline"
            >
              Sign in
            </button>
          </p>
        </form>
      </section>
    </>
  )
}

export default SignUpPage
