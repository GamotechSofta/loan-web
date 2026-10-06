import { useEffect, useState } from 'react'

const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:5000'

function formatDate(value) {
  if (!value) return '—'
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return '—'
  return date.toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' })
}

function scoreBand(score) {
  const value = Number(score)
  if (!Number.isFinite(value) || value <= 0) return null
  if (value >= 750) return { label: 'Excellent', className: 'bg-emerald-50 text-emerald-800' }
  if (value >= 700) return { label: 'Good', className: 'bg-emerald-50 text-emerald-800' }
  if (value >= 650) return { label: 'Fair', className: 'bg-amber-50 text-amber-800' }
  return { label: 'Needs attention', className: 'bg-rose-50 text-rose-800' }
}

function CibilPage({ userProfile, userToken, onSignIn, onApplyNow }) {
  const [report, setReport] = useState(userProfile?.cibilReport || null)
  const [canCheck, setCanCheck] = useState(Boolean(userProfile?.canCheckCibil))
  const [loadingReport, setLoadingReport] = useState(false)
  const [checking, setChecking] = useState(false)
  const [error, setError] = useState('')
  const [message, setMessage] = useState('')
  const [blockedMessage, setBlockedMessage] = useState('')

  useEffect(() => {
    if (!userToken) {
      setReport(null)
      setCanCheck(false)
      setBlockedMessage('')
      setError('')
      return undefined
    }

    let cancelled = false

    async function loadReport() {
      setLoadingReport(true)
      setError('')
      try {
        const response = await fetch(`${API_BASE}/api/user/cibil`, {
          headers: { Authorization: `Bearer ${userToken}` },
        })
        const data = await response.json()
        if (cancelled) return
        if (response.ok && data.success) {
          setReport(data.data?.cibilReport || null)
          setCanCheck(Boolean(data.data?.canCheckCibil))
          setBlockedMessage('')
        } else {
          setCanCheck(false)
          setBlockedMessage(data.message || 'CIBIL report is not available right now.')
        }
      } catch {
        if (!cancelled) setError('Could not reach the server. Please try again.')
      } finally {
        if (!cancelled) setLoadingReport(false)
      }
    }

    loadReport()
    return () => {
      cancelled = true
    }
  }, [userToken])

  async function handleCheckCibil() {
    if (!userToken || checking) return
    setChecking(true)
    setError('')
    setMessage('')
    try {
      const response = await fetch(`${API_BASE}/api/user/cibil/request`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${userToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ consent: 'Y' }),
      })
      const data = await response.json()
      if (response.ok && data.success) {
        setReport(data.data?.cibilReport || report)
        setCanCheck(true)
        setMessage(data.message || 'CIBIL report requested.')
      } else {
        setError(data.message || 'Could not fetch CIBIL report.')
      }
    } catch {
      setError('Could not reach the server. Please try again.')
    } finally {
      setChecking(false)
    }
  }

  const score = report?.score ?? report?.summary?.score
  const band = scoreBand(score)
  const status = report?.status || 'idle'

  return (
    <>
      <section className="brand-hero-bg px-4 py-14 text-white sm:px-6 lg:px-8 lg:py-16">
        <div className="mx-auto max-w-6xl">
          <div className="mb-5 inline-flex rounded-2xl bg-white px-4 py-2">
            <p className="text-sm font-bold text-[var(--navy)]">Credit score</p>
          </div>
          <h1 className="max-w-3xl text-4xl font-bold leading-tight sm:text-5xl">Check your CIBIL score</h1>
          <p className="mt-4 max-w-2xl text-base leading-relaxed text-white/90 sm:text-lg">
            See your credit score and report status while your loan application is in progress.
          </p>
        </div>
      </section>

      <section className="px-4 py-12 sm:px-6 lg:px-8">
        <div className="mx-auto max-w-3xl">
          {!userProfile ? (
            <div className="rounded-2xl border border-[var(--line)] bg-white p-6 shadow-sm sm:p-8">
              <h2 className="text-2xl font-semibold text-[var(--navy)]">Sign in to check your score</h2>
              <p className="mt-2 text-sm leading-relaxed text-slate-600">
                CIBIL reports are available to signed-in customers with an active loan application.
              </p>
              <button
                type="button"
                onClick={onSignIn}
                className="mt-6 rounded-2xl bg-[var(--navy)] px-5 py-3 text-sm font-semibold text-white hover:bg-black"
              >
                Sign In
              </button>
            </div>
          ) : (
            <div className="space-y-5">
              <div className="rounded-2xl border border-[var(--line)] bg-white p-6 shadow-sm sm:p-8">
                <div className="flex flex-wrap items-start justify-between gap-4">
                  <div>
                    <p className="text-xs font-semibold uppercase tracking-[0.14em] text-black/45">
                      CIBIL score
                    </p>
                    <p className="mt-2 text-5xl font-bold tracking-tight text-[var(--navy)]">
                      {score ?? '—'}
                    </p>
                    {band ? (
                      <span className={`mt-3 inline-flex rounded-full px-3 py-1 text-xs font-semibold ${band.className}`}>
                        {band.label}
                      </span>
                    ) : (
                      <p className="mt-3 text-sm text-slate-500">
                        {loadingReport ? 'Loading your report…' : 'No score yet. Check CIBIL to fetch it.'}
                      </p>
                    )}
                  </div>
                  {canCheck ? (
                    <button
                      type="button"
                      disabled={checking}
                      onClick={handleCheckCibil}
                      className="rounded-2xl bg-[var(--gold)] px-5 py-3 text-sm font-semibold text-white hover:bg-[#9a7234] disabled:opacity-60"
                    >
                      {checking ? 'Checking…' : status === 'ready' ? 'Refresh CIBIL' : 'Check CIBIL'}
                    </button>
                  ) : null}
                </div>

                <div className="mt-6 grid gap-3 sm:grid-cols-3">
                  <div className="rounded-xl border border-[var(--line)] bg-[var(--surface-muted)] px-4 py-3">
                    <p className="text-[11px] uppercase tracking-wide text-slate-500">Status</p>
                    <p className="mt-1 text-sm font-semibold capitalize text-slate-900">{status}</p>
                  </div>
                  <div className="rounded-xl border border-[var(--line)] bg-[var(--surface-muted)] px-4 py-3">
                    <p className="text-[11px] uppercase tracking-wide text-slate-500">Updated</p>
                    <p className="mt-1 text-sm font-semibold text-slate-900">
                      {report?.updatedAt ? formatDate(report.updatedAt) : '—'}
                    </p>
                  </div>
                  <div className="rounded-xl border border-[var(--line)] bg-[var(--surface-muted)] px-4 py-3">
                    <p className="text-[11px] uppercase tracking-wide text-slate-500">Name on report</p>
                    <p className="mt-1 truncate text-sm font-semibold text-slate-900">
                      {report?.summary?.name || userProfile.fullName || '—'}
                    </p>
                  </div>
                </div>

                {status === 'pending' ? (
                  <p className="mt-4 text-sm text-slate-600">
                    Your report has been requested. Refresh in a moment if the score is still empty.
                  </p>
                ) : null}
                {report?.error ? <p className="mt-4 text-sm text-rose-600">{report.error}</p> : null}
                {error ? <p className="mt-4 text-sm text-rose-600">{error}</p> : null}
                {message ? <p className="mt-4 text-sm font-medium text-emerald-700">{message}</p> : null}
                {blockedMessage ? (
                  <div className="mt-4 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-900">
                    <p>{blockedMessage}</p>
                    {onApplyNow ? (
                      <button
                        type="button"
                        onClick={onApplyNow}
                        className="mt-3 rounded-xl bg-[var(--navy)] px-4 py-2 text-sm font-semibold text-white hover:bg-black"
                      >
                        Apply for a loan
                      </button>
                    ) : null}
                  </div>
                ) : null}
              </div>

              <p className="text-xs leading-relaxed text-slate-500">
                Checking CIBIL uses the consent already given on your loan application. Scores are shown only while
                that application is active.
              </p>
            </div>
          )}
        </div>
      </section>
    </>
  )
}

export default CibilPage
