import { useCallback, useEffect, useMemo, useState } from 'react'

const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:5000'
const TOKEN_KEY = 'admin_auth_token'

const DOC_LABELS = {
  aadhaarDoc: 'Aadhaar Document',
  panDoc: 'PAN Document',
  salarySlips: 'Salary Slips',
  bankStatements: 'Bank Statements',
  photograph: 'Profile Photograph',
  signature: 'Signature',
  selfie: 'Selfie',
}

const FIELD_ITEMS = [
  { key: 'fullName', label: 'Full Name' },
  { key: 'parentName', label: "Father's / Mother's Name" },
  { key: 'dateOfBirth', label: 'Date of Birth' },
  { key: 'gender', label: 'Gender' },
  { key: 'mobile', label: 'Mobile Number' },
  { key: 'email', label: 'Email Address' },
  { key: 'residentialAddress', label: 'Residential Address' },
  { key: 'permanentAddress', label: 'Permanent Address' },
  { key: 'occupation', label: 'Occupation' },
  { key: 'employerDetails', label: 'Employer Details' },
  { key: 'incomeDetails', label: 'Income Details' },
  { key: 'educationalInfo', label: 'Educational Information' },
  { key: 'nomineeName', label: 'Nominee Name' },
  { key: 'nomineeRelation', label: 'Nominee Relation' },
  { key: 'nomineeMobile', label: 'Nominee Mobile' },
  { key: 'emergencyContactName', label: 'Emergency Contact Name' },
  { key: 'emergencyContactRelation', label: 'Emergency Contact Relation' },
  { key: 'emergencyContactMobile', label: 'Emergency Contact Mobile' },
  { key: 'reference1Name', label: 'Reference 1 Name' },
  { key: 'reference1Mobile', label: 'Reference 1 Mobile' },
  { key: 'reference2Name', label: 'Reference 2 Name' },
  { key: 'reference2Mobile', label: 'Reference 2 Mobile' },
  { key: 'username', label: 'Username' },
  { key: 'customerFeedback', label: 'Customer Feedback' },
  { key: 'communicationPreferences', label: 'Communication Preferences' },
  { key: 'aadhaar', label: 'Aadhaar' },
  { key: 'pan', label: 'PAN' },
  { key: 'accountNumber', label: 'Account Number' },
  { key: 'ifsc', label: 'IFSC' },
  { key: 'pinCode', label: 'PIN Code' },
  { key: 'loanPurpose', label: 'Loan Purpose' },
  { key: 'loanAmount', label: 'Loan Amount' },
  { key: 'eSignConsent', label: 'eSign Consent' },
]

const SIDEBAR_ITEMS = [
  { id: 'not_verified', label: 'Not Verified', statKey: 'notVerified', group: 'Applications' },
  { id: 'pending', label: 'Pending KYC', statKey: 'pendingKyc', group: 'Applications' },
  { id: 'all', label: 'All Submissions', statKey: 'totalSubmissions', group: 'Applications' },
  { id: 'verified', label: 'Verified', statKey: 'verified', group: 'Applications' },
  { id: 'users', label: 'Total Users', statKey: 'totalUsers', group: 'Accounts' },
  { id: 'disbursed', label: 'Disbursed Loans', statKey: 'disbursedLoans', group: 'Accounts' },
]

function getStoredToken() {
  return localStorage.getItem(TOKEN_KEY) || ''
}

function formatDate(value) {
  if (!value) return '—'
  return new Date(value).toLocaleString('en-IN', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

function formatCurrency(value) {
  const amount = Number(value) || 0
  return `₹${amount.toLocaleString('en-IN')}`
}

function getSubmissionInitials(name) {
  const words = String(name || 'User')
    .trim()
    .split(/\s+/)
    .filter(Boolean)
  return words
    .slice(0, 2)
    .map((word) => word[0]?.toUpperCase() || '')
    .join('')
}

function getStatusStyles(status) {
  if (status === 'verified' || status === 'accepted') {
    return 'border-emerald-200 bg-emerald-50 text-emerald-800'
  }
  if (status === 'rejected') {
    return 'border-rose-200 bg-rose-50 text-rose-800'
  }
  if (status === 'in_review') {
    return 'border-slate-300 bg-slate-50 text-slate-700'
  }
  return 'border-slate-200 bg-white text-slate-600'
}

function getStatusDot(status) {
  if (status === 'verified' || status === 'accepted') return 'bg-emerald-600'
  if (status === 'rejected') return 'bg-rose-600'
  return 'bg-slate-400'
}

function formatStatusLabel(status) {
  return String(status || 'pending').replace(/_/g, ' ')
}

function StatusBadge({ status }) {
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded border px-2 py-0.5 text-[11px] font-medium uppercase tracking-wide ${getStatusStyles(
        status,
      )}`}
    >
      <span className={`h-1.5 w-1.5 rounded-full ${getStatusDot(status)}`} />
      {formatStatusLabel(status)}
    </span>
  )
}

function getFieldDisplayValue(submission, key) {
  if (key === 'loanAmount') return formatCurrency(submission.loanAmount)
  if (key === 'eSignConsent') return submission.eSignConsent ? 'Yes' : 'No'
  if (key === 'income' && submission.income) return formatCurrency(submission.income)
  if (key === 'gender') {
    return String(submission.gender || '')
      .replace(/_/g, ' ')
      .replace(/\b\w/g, (c) => c.toUpperCase()) || '—'
  }
  if (key === 'communicationPreferences') {
    const prefs = submission.communicationPreferences || {}
    const selected = Object.entries(prefs)
      .filter(([, enabled]) => enabled)
      .map(([name]) => name.toUpperCase())
    return selected.length ? selected.join(', ') : '—'
  }
  if (key === 'residentialAddress') {
    return submission.residentialAddress || submission.address || '—'
  }
  if (key === 'incomeDetails') {
    return submission.incomeDetails || submission.income || '—'
  }
  if (key === 'occupation') {
    return submission.occupation || submission.employment || '—'
  }
  return submission[key] || '—'
}

function countItemProgress(submission) {
  const fields = Object.values(submission.verifications?.fields || {})
  const docs = Object.values(submission.verifications?.documents || {})
  const all = [...fields, ...docs]
  const accepted = all.filter((item) => item.status === 'accepted').length
  const rejected = all.filter((item) => item.status === 'rejected').length
  return { total: all.length, accepted, rejected, pending: all.length - accepted - rejected }
}

function LoginPage({ onLogin }) {
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  async function handleSubmit(event) {
    event.preventDefault()
    if (loading) return

    setLoading(true)
    setError('')

    try {
      const response = await fetch(`${API_BASE}/api/admin/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username: username.trim(), password }),
      })
      const data = await response.json()

      if (response.ok && data.success && data.data?.token) {
        onLogin(data.data.token, data.data.username)
      } else {
        setError(data.message || 'Login failed.')
      }
    } catch {
      setError('Could not reach the server. Make sure the backend is running.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-slate-100 px-4 py-8">
      <form
        onSubmit={handleSubmit}
        className="w-full max-w-md rounded-2xl border border-slate-200 bg-white p-6 shadow-sm sm:p-8"
      >
        <div className="mb-6">
          <p className="text-sm font-medium text-blue-700">SAKAAR MICROCREDIT FOUNDATION</p>
          <h1 className="mt-1 text-2xl font-semibold text-slate-900">Admin Login</h1>
          <p className="mt-1 text-sm text-slate-600">Sign in to review KYC submissions.</p>
        </div>

        {error && (
          <div className="mb-4 rounded-lg bg-red-50 px-4 py-3 text-sm text-red-600">{error}</div>
        )}

        <label className="mb-4 block">
          <span className="mb-1.5 block text-sm font-medium text-slate-700">Username</span>
          <input
            type="text"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            autoComplete="username"
            className="w-full rounded-lg border border-slate-300 px-3 py-2.5 text-sm text-slate-800 outline-none focus:border-blue-500"
            placeholder="Enter username"
            required
          />
        </label>

        <label className="mb-6 block">
          <span className="mb-1.5 block text-sm font-medium text-slate-700">Password</span>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
            className="w-full rounded-lg border border-slate-300 px-3 py-2.5 text-sm text-slate-800 outline-none focus:border-blue-500"
            placeholder="Enter password"
            required
          />
        </label>

        <button
          type="submit"
          disabled={loading || !username.trim() || !password}
          className="w-full rounded-lg bg-blue-700 px-4 py-2.5 text-sm font-semibold text-white hover:bg-blue-800 disabled:cursor-not-allowed disabled:bg-slate-300"
        >
          {loading ? 'Signing in...' : 'Sign in'}
        </button>
      </form>
    </main>
  )
}

function SidebarStatButton({ item, count, active, onClick }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`group flex w-full items-center justify-between rounded-lg px-3 py-2 text-left transition ${
        active
          ? 'bg-[#0b254a] text-white'
          : 'text-slate-600 hover:bg-slate-100 hover:text-slate-900'
      }`}
    >
      <span className="text-[13px] font-medium tracking-tight">{item.label}</span>
      <span
        className={`min-w-[1.5rem] text-right text-[12px] tabular-nums ${
          active ? 'text-white/70' : 'text-slate-400 group-hover:text-slate-500'
        }`}
      >
        {count}
      </span>
    </button>
  )
}

function ItemStatusButtons({ currentStatus, disabled, onChange }) {
  const options = [
    {
      value: 'accepted',
      label: 'Accept',
      active: 'bg-emerald-600 text-white border-emerald-600',
      idle: 'bg-white text-emerald-700 hover:bg-emerald-50',
    },
    {
      value: 'rejected',
      label: 'Reject',
      active: 'bg-rose-600 text-white border-rose-600',
      idle: 'bg-white text-rose-700 hover:bg-rose-50',
    },
    {
      value: 'pending',
      label: 'Pending',
      active: 'bg-slate-700 text-white border-slate-700',
      idle: 'bg-white text-slate-600 hover:bg-slate-50',
    },
  ]

  return (
    <div className="inline-flex overflow-hidden rounded-md border border-slate-300">
      {options.map((option, index) => {
        const isActive = currentStatus === option.value
        return (
          <button
            key={option.value}
            type="button"
            disabled={disabled || isActive}
            onClick={() => onChange(option.value)}
            className={`px-3 py-1.5 text-xs font-semibold transition disabled:cursor-default ${
              index > 0 ? 'border-l border-slate-300' : ''
            } ${isActive ? option.active : option.idle}`}
          >
            {option.label}
          </button>
        )
      })}
    </div>
  )
}

function VerificationRow({ label, value, status, updatedAt, disabled, onStatusChange, extra }) {
  return (
    <div className="grid gap-3 border-b border-slate-200 px-4 py-4 last:border-b-0 lg:grid-cols-[1.4fr_1fr_auto] lg:items-start">
      <div className="min-w-0">
        <p className="text-xs font-medium uppercase tracking-wide text-slate-500">{label}</p>
        <p className="mt-1 break-words text-sm text-slate-900">{value}</p>
        {extra}
      </div>
      <div className="space-y-1">
        <StatusBadge status={status || 'pending'} />
        <p className="text-xs text-slate-400">Checked {formatDate(updatedAt)}</p>
      </div>
      <ItemStatusButtons
        currentStatus={status || 'pending'}
        disabled={disabled}
        onChange={onStatusChange}
      />
    </div>
  )
}

function ApplicantListCard({ submission, onOpen }) {
  const progress = countItemProgress(submission)
  const lastUpdated = submission.updatedAt || submission.reviewedAt || submission.submittedAt

  return (
    <button
      type="button"
      onClick={() => onOpen(submission.id)}
      className="w-full border-b border-slate-200 bg-white px-5 py-4 text-left transition last:border-b-0 hover:bg-slate-50"
    >
      <div className="flex items-start gap-4">
        <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full border border-slate-300 bg-slate-50 text-sm font-semibold text-slate-700">
          {getSubmissionInitials(submission.fullName)}
        </div>
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <p className="text-base font-semibold text-slate-900">
              {submission.fullName || 'Unnamed applicant'}
            </p>
            <StatusBadge status={submission.status} />
          </div>
          <div className="mt-3 grid gap-1.5 text-sm text-slate-600 sm:grid-cols-2">
            <p>Mobile: {submission.mobile || '—'}</p>
            <p>PAN: {submission.pan || '—'}</p>
            <p>Loan: {formatCurrency(submission.loanAmount)}</p>
            <p>
              Review progress: {progress.accepted}/{progress.total}
            </p>
            <p className="sm:col-span-2 text-slate-500">Updated {formatDate(lastUpdated)}</p>
          </div>
          <p className="mt-3 text-sm font-medium text-slate-800">Review application →</p>
        </div>
      </div>
    </button>
  )
}

function VerificationDetail({
  submission,
  token,
  updatingKey,
  onBack,
  onItemStatusChange,
  onOverallStatusChange,
  onCibilRequest,
  cibilLoading,
  cibilError,
}) {
  const progress = countItemProgress(submission)
  const docs = submission.documents || {}
  const fieldStatuses = submission.verifications?.fields || {}
  const docStatuses = submission.verifications?.documents || {}
  const cibil = submission.cibilReport || {}
  const canCheckCibil = Boolean(submission.canCheckCibil)

  return (
    <div className="space-y-6">
      <div className="border border-slate-200 bg-white">
        <div className="border-b border-slate-200 px-5 py-4">
          <button
            type="button"
            onClick={onBack}
            className="mb-4 text-sm font-medium text-slate-600 hover:text-slate-900"
          >
            ← Back to applicants
          </button>
          <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
            <div className="flex items-start gap-4">
              <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full border border-slate-300 bg-slate-50 text-sm font-semibold text-slate-700">
                {getSubmissionInitials(submission.fullName)}
              </div>
              <div>
                <div className="flex flex-wrap items-center gap-2">
                  <h2 className="text-xl font-semibold text-slate-900">
                    {submission.fullName || 'Unnamed applicant'}
                  </h2>
                  <StatusBadge status={submission.status} />
                </div>
                <p className="mt-1 text-sm text-slate-600">
                  {submission.mobile} · {submission.id}
                </p>
                <p className="mt-1 text-xs text-slate-500">
                  Submitted {formatDate(submission.submittedAt)} · Updated{' '}
                  {formatDate(
                    submission.updatedAt || submission.reviewedAt || submission.submittedAt,
                  )}
                </p>
              </div>
            </div>

            <div className="min-w-[220px] border border-slate-200 bg-slate-50 px-4 py-3 text-sm">
              <p className="text-xs uppercase tracking-wide text-slate-500">Review progress</p>
              <p className="mt-1 text-lg font-semibold text-slate-900">
                {progress.accepted} / {progress.total}
              </p>
              <p className="mt-1 text-xs text-slate-500">
                {progress.pending} pending · {progress.rejected} rejected
              </p>
              <div className="mt-3 flex flex-wrap gap-2">
                <button
                  type="button"
                  disabled={Boolean(updatingKey)}
                  onClick={() => onOverallStatusChange(submission.id, 'verified')}
                  className="rounded-md border border-emerald-600 bg-emerald-600 px-3 py-1.5 text-xs font-semibold text-white hover:bg-emerald-700 disabled:opacity-60"
                >
                  Verify all
                </button>
                <button
                  type="button"
                  disabled={Boolean(updatingKey)}
                  onClick={() => onOverallStatusChange(submission.id, 'rejected')}
                  className="rounded-md border border-rose-600 bg-white px-3 py-1.5 text-xs font-semibold text-rose-700 hover:bg-rose-50 disabled:opacity-60"
                >
                  Reject all
                </button>
              </div>
            </div>
          </div>
        </div>

        <div className="grid gap-px border-t border-slate-200 bg-slate-200 sm:grid-cols-4">
          {[
            { label: 'Loan amount', value: formatCurrency(submission.loanAmount) },
            { label: 'Processing fee', value: formatCurrency(submission.processingFee) },
            { label: 'EMI', value: formatCurrency(submission.emi) },
            { label: 'Net credited', value: formatCurrency(submission.netCreditedAmount) },
          ].map((item) => (
            <div key={item.label} className="bg-white px-4 py-3">
              <p className="text-[11px] uppercase tracking-wide text-slate-500">{item.label}</p>
              <p className="mt-1 text-sm font-semibold text-slate-900">{item.value}</p>
            </div>
          ))}
        </div>
      </div>

      <section className="border border-slate-200 bg-white">
        <div className="border-b border-slate-200 px-5 py-4 flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <h3 className="text-base font-semibold text-slate-900">CIBIL report</h3>
            <p className="mt-1 text-sm text-slate-500">
              Available only while this applicant has an active loan application.
            </p>
          </div>
          {canCheckCibil ? (
            <button
              type="button"
              disabled={cibilLoading || Boolean(updatingKey)}
              onClick={() => onCibilRequest(submission.id)}
              className="rounded-md border border-slate-800 bg-slate-900 px-3 py-1.5 text-xs font-semibold text-white hover:bg-black disabled:opacity-60"
            >
              {cibilLoading ? 'Fetching…' : cibil.status === 'ready' ? 'Refresh CIBIL' : 'Check CIBIL'}
            </button>
          ) : null}
        </div>
        <div className="px-5 py-4 space-y-3 text-sm">
          {!canCheckCibil ? (
            <p className="text-slate-500">
              CIBIL is locked because this loan application is no longer active.
            </p>
          ) : (
            <>
              <div className="grid gap-3 sm:grid-cols-3">
                <div className="border border-slate-200 px-3 py-2">
                  <p className="text-[11px] uppercase tracking-wide text-slate-500">Status</p>
                  <p className="mt-1 font-semibold text-slate-900">{cibil.status || 'idle'}</p>
                </div>
                <div className="border border-slate-200 px-3 py-2">
                  <p className="text-[11px] uppercase tracking-wide text-slate-500">Score</p>
                  <p className="mt-1 font-semibold text-slate-900">
                    {cibil.score ?? cibil.summary?.score ?? '—'}
                  </p>
                </div>
                <div className="border border-slate-200 px-3 py-2">
                  <p className="text-[11px] uppercase tracking-wide text-slate-500">Updated</p>
                  <p className="mt-1 font-semibold text-slate-900">
                    {cibil.updatedAt ? formatDate(cibil.updatedAt) : '—'}
                  </p>
                </div>
              </div>
              {cibil.error ? <p className="text-rose-600">{cibil.error}</p> : null}
              {cibilError ? <p className="text-rose-600">{cibilError}</p> : null}
              {cibil.report ? (
                <pre className="max-h-72 overflow-auto border border-slate-200 bg-slate-50 p-3 text-xs text-slate-700">
                  {JSON.stringify(cibil.report, null, 2)}
                </pre>
              ) : cibil.status === 'pending' ? (
                <p className="text-slate-500">
                  Report requested. Waiting for provider callback or refresh.
                </p>
              ) : (
                <p className="text-slate-500">No CIBIL report fetched yet.</p>
              )}
            </>
          )}
        </div>
      </section>

      <section className="border border-slate-200 bg-white">
        <div className="border-b border-slate-200 px-5 py-4">
          <h3 className="text-base font-semibold text-slate-900">Applicant information</h3>
          <p className="mt-1 text-sm text-slate-500">
            Review each detail carefully before accepting or rejecting.
          </p>
        </div>
        <div>
          {FIELD_ITEMS.map((field) => {
            const itemKey = `field:${field.key}`
            const verification = fieldStatuses[field.key] || { status: 'pending', updatedAt: null }
            return (
              <VerificationRow
                key={field.key}
                label={field.label}
                value={getFieldDisplayValue(submission, field.key)}
                status={verification.status}
                updatedAt={verification.updatedAt}
                disabled={updatingKey === itemKey}
                onStatusChange={(status) =>
                  onItemStatusChange(submission.id, 'field', field.key, status)
                }
              />
            )
          })}
        </div>
      </section>

      <section className="border border-slate-200 bg-white">
        <div className="border-b border-slate-200 px-5 py-4">
          <h3 className="text-base font-semibold text-slate-900">Uploaded documents</h3>
          <p className="mt-1 text-sm text-slate-500">
            Open the file, then mark the verification decision.
          </p>
        </div>
        <div>
          {Object.keys(docs).length === 0 ? (
            <p className="px-5 py-8 text-sm text-slate-500">No documents uploaded.</p>
          ) : (
            Object.entries(docs).map(([key, doc]) => {
              const itemKey = `document:${key}`
              const verification = docStatuses[key] || { status: 'pending', updatedAt: null }
              return (
                <VerificationRow
                  key={key}
                  label={DOC_LABELS[key] || key}
                  value={doc.originalName || doc.fileName || 'Uploaded file'}
                  status={verification.status}
                  updatedAt={verification.updatedAt}
                  disabled={updatingKey === itemKey}
                  onStatusChange={(status) =>
                    onItemStatusChange(submission.id, 'document', key, status)
                  }
                  extra={
                    <a
                      href={`${API_BASE}${doc.url}?token=${encodeURIComponent(token)}`}
                      target="_blank"
                      rel="noreferrer"
                      className="mt-2 inline-flex text-sm font-medium text-slate-800 underline underline-offset-2 hover:text-black"
                    >
                      Open document
                    </a>
                  }
                />
              )
            })
          )}
        </div>
      </section>
    </div>
  )
}

function Dashboard({ token, onLogout }) {
  const [submissions, setSubmissions] = useState([])
  const [stats, setStats] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [selectedId, setSelectedId] = useState(null)
  const [searchTerm, setSearchTerm] = useState('')
  const [activeFilter, setActiveFilter] = useState('not_verified')
  const [updatingKey, setUpdatingKey] = useState(null)
  const [cibilLoading, setCibilLoading] = useState(false)
  const [cibilError, setCibilError] = useState('')
  const [sidebarOpen, setSidebarOpen] = useState(() => {
    const stored = localStorage.getItem('admin_sidebar_open')
    return stored === null ? true : stored === 'true'
  })

  useEffect(() => {
    localStorage.setItem('admin_sidebar_open', String(sidebarOpen))
  }, [sidebarOpen])

  const fetchDashboardData = useCallback(async ({ silent = false } = {}) => {
    if (!silent) {
      setLoading(true)
      setError('')
    }
    try {
      const [submissionsRes, statsRes] = await Promise.all([
        fetch(`${API_BASE}/api/kyc/submissions`, {
          headers: { Authorization: `Bearer ${token}` },
        }),
        fetch(`${API_BASE}/api/admin/stats`, {
          headers: { Authorization: `Bearer ${token}` },
        }),
      ])

      if (submissionsRes.status === 401 || submissionsRes.status === 403) {
        onLogout()
        return
      }

      const submissionsData = await submissionsRes.json()
      const statsData = await statsRes.json()

      if (submissionsRes.ok && submissionsData.success) {
        setSubmissions(submissionsData.data || [])
      } else {
        setError(submissionsData.message || 'Failed to load submissions.')
      }

      if (statsRes.ok && statsData.success) {
        setStats(statsData.data)
      }
    } catch {
      setError('Could not reach the server. Make sure the backend is running.')
    } finally {
      if (!silent) setLoading(false)
    }
  }, [token, onLogout])

  useEffect(() => {
    fetchDashboardData()
  }, [fetchDashboardData])

  useEffect(() => {
    const timer = window.setInterval(
      () => fetchDashboardData({ silent: true }),
      10000,
    )
    return () => window.clearInterval(timer)
  }, [fetchDashboardData])

  async function handleOverallStatusChange(submissionId, status) {
    setUpdatingKey(`overall:${submissionId}`)
    try {
      const response = await fetch(`${API_BASE}/api/admin/kyc/${submissionId}/status`, {
        method: 'PATCH',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ status }),
      })
      const data = await response.json()

      if (response.status === 401 || response.status === 403) {
        onLogout()
        return
      }

      if (response.ok && data.success) {
        setSubmissions((prev) =>
          prev.map((item) => (item.id === submissionId ? data.data : item)),
        )
        await fetchDashboardData()
      } else {
        setError(data.message || 'Failed to update status.')
      }
    } catch {
      setError('Could not update submission status.')
    } finally {
      setUpdatingKey(null)
    }
  }

  async function handleItemStatusChange(submissionId, type, key, status) {
    const itemKey = `${type}:${key}`
    setUpdatingKey(itemKey)
    try {
      const response = await fetch(`${API_BASE}/api/admin/kyc/${submissionId}/item-status`, {
        method: 'PATCH',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ type, key, status }),
      })
      const data = await response.json()

      if (response.status === 401 || response.status === 403) {
        onLogout()
        return
      }

      if (response.ok && data.success) {
        setSubmissions((prev) =>
          prev.map((item) => (item.id === submissionId ? data.data : item)),
        )
        const statsRes = await fetch(`${API_BASE}/api/admin/stats`, {
          headers: { Authorization: `Bearer ${token}` },
        })
        const statsData = await statsRes.json()
        if (statsRes.ok && statsData.success) {
          setStats(statsData.data)
        }
      } else {
        setError(data.message || 'Failed to update item status.')
      }
    } catch {
      setError('Could not update verification item.')
    } finally {
      setUpdatingKey(null)
    }
  }

  async function handleCibilRequest(submissionId) {
    setCibilLoading(true)
    setCibilError('')
    try {
      const response = await fetch(`${API_BASE}/api/admin/cibil/${submissionId}/request`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({}),
      })
      const data = await response.json()

      if (response.status === 401 || response.status === 403) {
        onLogout()
        return
      }

      if (response.ok && data.success) {
        setSubmissions((prev) =>
          prev.map((item) =>
            item.id === submissionId
              ? {
                  ...item,
                  ...data.data,
                  canCheckCibil: true,
                }
              : item,
          ),
        )
        await fetchDashboardData({ silent: true })
      } else {
        setCibilError(data.message || 'Failed to fetch CIBIL report.')
      }
    } catch {
      setCibilError('Could not reach the server for CIBIL fetch.')
    } finally {
      setCibilLoading(false)
    }
  }

  const filteredSubmissions = useMemo(() => {
    let list = submissions

    if (activeFilter === 'verified') {
      list = list.filter((item) => item.status === 'verified')
    } else if (activeFilter === 'not_verified') {
      list = list.filter((item) => item.status !== 'verified')
    } else if (activeFilter === 'pending') {
      list = list.filter((item) => item.status === 'submitted' || item.status === 'in_review')
    } else if (activeFilter === 'disbursed') {
      list = list.filter((item) => item.status === 'verified')
    } else if (activeFilter === 'users') {
      const seen = new Set()
      list = list.filter((item) => {
        if (seen.has(item.mobile)) return false
        seen.add(item.mobile)
        return true
      })
    }

    const query = searchTerm.trim().toLowerCase()
    if (!query) return list

    return list.filter((submission) => {
      const haystack = [
        submission.fullName,
        submission.mobile,
        submission.pan,
        submission.aadhaar,
        submission.address,
        submission.id,
      ]
        .join(' ')
        .toLowerCase()

      return haystack.includes(query)
    })
  }, [submissions, searchTerm, activeFilter])

  const selectedSubmission = submissions.find((item) => item.id === selectedId) || null
  const activeFilterLabel =
    SIDEBAR_ITEMS.find((item) => item.id === activeFilter)?.label || 'All Submissions'

  return (
    <main className="min-h-screen bg-[#f4f6f8]">
      <div className="flex min-h-screen items-start">
        <aside
          className={`sticky top-0 z-20 h-screen shrink-0 self-start overflow-hidden border-slate-200 bg-white transition-[width,opacity,border-color] duration-300 ease-in-out ${
            sidebarOpen
              ? 'w-full border-r opacity-100 lg:w-[260px]'
              : 'pointer-events-none w-0 border-r-0 opacity-0'
          }`}
          aria-hidden={!sidebarOpen}
        >
          <div className="flex h-screen w-full flex-col lg:w-[260px]">
            <div className="flex items-center justify-between gap-3 px-5 py-5">
              <div className="flex min-w-0 items-center gap-3">
                <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-[#0b254a] text-xs font-bold tracking-wide text-white">
                  SF
                </div>
                <div className="min-w-0">
                  <p className="truncate text-sm font-semibold text-[#0b254a]">Sakaar Admin</p>
                  <p className="truncate text-xs text-slate-500">Verification desk</p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setSidebarOpen(false)}
                title="Hide sidebar"
                aria-label="Hide sidebar"
                className="rounded-md px-2 py-1 text-xs font-medium text-slate-400 transition hover:bg-slate-100 hover:text-slate-700"
              >
                Hide
              </button>
            </div>

            <nav className="flex-1 overflow-y-auto px-3 pb-4">
              {['Applications', 'Accounts'].map((group) => (
                <div key={group} className={group === 'Accounts' ? 'mt-6' : 'mt-1'}>
                  <p className="mb-2 px-3 text-[11px] font-semibold uppercase tracking-[0.14em] text-slate-400">
                    {group}
                  </p>
                  <div className="space-y-0.5">
                    {SIDEBAR_ITEMS.filter((item) => item.group === group).map((item) => (
                      <SidebarStatButton
                        key={item.id}
                        item={item}
                        count={stats?.[item.statKey] ?? (loading ? '—' : 0)}
                        active={!selectedSubmission && activeFilter === item.id}
                        onClick={() => {
                          setSelectedId(null)
                          setActiveFilter(item.id)
                        }}
                      />
                    ))}
                  </div>
                </div>
              ))}
            </nav>

            <div className="mt-auto border-t border-slate-200 px-4 py-4">
              <button
                type="button"
                onClick={onLogout}
                className="w-full rounded-lg px-3 py-2 text-left text-[13px] font-medium text-slate-600 transition hover:bg-slate-100 hover:text-slate-900"
              >
                Sign out
              </button>
            </div>
          </div>
        </aside>

        <section className="min-w-0 flex-1 px-4 py-6 transition-[padding] duration-300 ease-in-out sm:px-6 lg:px-8">
          <div className="mx-auto max-w-5xl">
            <div
              className={`overflow-hidden transition-all duration-300 ease-in-out ${
                sidebarOpen
                  ? 'mb-0 max-h-0 opacity-0'
                  : 'mb-4 max-h-16 opacity-100'
              }`}
            >
              <div className="flex flex-wrap items-center gap-2">
                <button
                  type="button"
                  onClick={() => setSidebarOpen(true)}
                  className="rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm font-medium text-slate-700 transition hover:bg-slate-50"
                >
                  Show menu
                </button>
                <button
                  type="button"
                  onClick={onLogout}
                  className="rounded-lg border border-slate-200 bg-white px-3 py-2 text-sm font-medium text-slate-700 transition hover:bg-slate-50"
                >
                  Sign out
                </button>
              </div>
            </div>

            {error && (
              <div className="mb-4 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-600">{error}</div>
            )}

            {selectedSubmission ? (
              <VerificationDetail
                submission={selectedSubmission}
                token={token}
                updatingKey={updatingKey}
                onBack={() => setSelectedId(null)}
                onItemStatusChange={handleItemStatusChange}
                onOverallStatusChange={handleOverallStatusChange}
                onCibilRequest={handleCibilRequest}
                cibilLoading={cibilLoading}
                cibilError={cibilError}
              />
            ) : (
              <>
                <header className="mb-6 flex flex-col gap-4 xl:flex-row xl:items-end xl:justify-between">
                  <div>
                    <p className="text-sm font-medium text-slate-500">Applicant verification</p>
                    <h2 className="mt-1 text-3xl font-semibold text-slate-900">{activeFilterLabel}</h2>
                    <p className="mt-2 text-sm text-slate-600">
                      Open an applicant to verify each profile field and uploaded document.
                    </p>
                  </div>
                  <div className="w-full max-w-md">
                    <label className="mb-1.5 block text-sm font-medium text-slate-700">
                      Search applicants
                    </label>
                    <input
                      type="text"
                      value={searchTerm}
                      onChange={(e) => setSearchTerm(e.target.value)}
                      placeholder="Search by name, mobile, PAN, Aadhaar"
                      className="w-full border border-slate-300 bg-white px-4 py-3 text-sm text-slate-800 outline-none focus:border-slate-500"
                    />
                  </div>
                </header>

                {loading ? (
                  <p className="border border-slate-200 bg-white px-6 py-12 text-center text-sm text-slate-500">
                    Loading applicants...
                  </p>
                ) : filteredSubmissions.length === 0 ? (
                  <p className="border border-slate-200 bg-white px-6 py-12 text-center text-sm text-slate-500">
                    {submissions.length === 0
                      ? 'No KYC submissions yet.'
                      : 'No applicants match the selected filter or search.'}
                  </p>
                ) : (
                  <div className="space-y-0 divide-y divide-slate-200 border border-slate-200 bg-white">
                    {filteredSubmissions.map((submission) => (
                      <ApplicantListCard
                        key={submission.id}
                        submission={submission}
                        onOpen={setSelectedId}
                      />
                    ))}
                  </div>
                )}
              </>
            )}
          </div>
        </section>
      </div>
    </main>
  )
}

function App() {
  const [token, setToken] = useState(() => getStoredToken())
  const [checking, setChecking] = useState(Boolean(getStoredToken()))

  const handleLogout = useCallback(() => {
    localStorage.removeItem(TOKEN_KEY)
    setToken('')
  }, [])

  const handleLogin = useCallback((nextToken) => {
    localStorage.setItem(TOKEN_KEY, nextToken)
    setToken(nextToken)
  }, [])

  useEffect(() => {
    if (!token) {
      setChecking(false)
      return
    }

    let cancelled = false

    async function verifySession() {
      try {
        const response = await fetch(`${API_BASE}/api/admin/me`, {
          headers: { Authorization: `Bearer ${token}` },
        })
        const data = await response.json()

        if (!cancelled && !(response.ok && data.success)) {
          localStorage.removeItem(TOKEN_KEY)
          setToken('')
        }
      } catch {
        // Keep session if network is temporarily unavailable.
      } finally {
        if (!cancelled) setChecking(false)
      }
    }

    verifySession()
    return () => {
      cancelled = true
    }
  }, [token])

  if (checking) {
    return (
      <main className="flex min-h-screen items-center justify-center bg-slate-100">
        <p className="text-sm text-slate-500">Checking session...</p>
      </main>
    )
  }

  if (!token) {
    return <LoginPage onLogin={handleLogin} />
  }

  return <Dashboard token={token} onLogout={handleLogout} />
}

export default App
