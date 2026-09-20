import { useEffect, useMemo, useState } from 'react'
import { isLoanFullyApproved } from '../utils/userNotifications'

const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:5000'

const LOAN_PURPOSE_LABELS = {
  medical: 'Medical Emergency',
  education: 'Education',
  home: 'Home Expenses',
  travel: 'Travel',
  business: 'Business',
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

const DOC_LABELS = {
  aadhaarDoc: 'Aadhaar Document',
  panDoc: 'PAN Document',
  salarySlips: 'Salary Slips',
  bankStatements: 'Bank Statements',
  photograph: 'Profile Photograph',
  signature: 'Signature',
  selfie: 'Selfie',
}

const DETAIL_TABS = [
  { id: 'all', label: 'All items' },
  { id: 'accepted', label: 'Accepted' },
  { id: 'rejected', label: 'Rejected' },
  { id: 'pending', label: 'Pending' },
]

function formatCurrency(amount) {
  if (amount === undefined || amount === null || amount === '') return '—'
  return `₹${Number(amount).toLocaleString('en-IN')}`
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

function formatStatus(status) {
  return String(status || 'pending').replace(/_/g, ' ')
}

function getStatusStyles(status) {
  if (status === 'verified' || status === 'accepted') {
    return 'border-emerald-200 bg-emerald-50 text-emerald-800'
  }
  if (status === 'rejected') {
    return 'border-rose-200 bg-rose-50 text-rose-800'
  }
  if (status === 'in_review' || status === 'submitted') {
    return 'border-slate-300 bg-slate-50 text-slate-700'
  }
  return 'border-slate-200 bg-white text-slate-600'
}

function getStatusDot(status) {
  if (status === 'verified' || status === 'accepted') return 'bg-emerald-600'
  if (status === 'rejected') return 'bg-rose-600'
  return 'bg-slate-400'
}

function getFieldDisplayValue(source, key) {
  if (key === 'loanAmount') return formatCurrency(source?.loanAmount)
  if (key === 'eSignConsent') return source?.eSignConsent ? 'Yes' : 'No'
  if (key === 'income' && source?.income) return formatCurrency(source.income)
  if (key === 'loanPurpose') {
    return LOAN_PURPOSE_LABELS[source?.loanPurpose] || source?.loanPurpose || '—'
  }
  if (key === 'gender') {
    return String(source?.gender || '')
      .replace(/_/g, ' ')
      .replace(/\b\w/g, (c) => c.toUpperCase()) || '—'
  }
  if (key === 'communicationPreferences') {
    const prefs = source?.communicationPreferences || {}
    const selected = Object.entries(prefs)
      .filter(([, enabled]) => enabled)
      .map(([name]) => name.toUpperCase())
    return selected.length ? selected.join(', ') : '—'
  }
  if (key === 'residentialAddress') {
    return source?.residentialAddress || source?.address || '—'
  }
  if (key === 'incomeDetails') {
    return source?.incomeDetails || source?.income || '—'
  }
  if (key === 'occupation') {
    return source?.occupation || source?.employment || '—'
  }
  return source?.[key] || '—'
}

function LoanApprovedBanner({ application, profile }) {
  const loanAmount = application?.loanAmount || profile?.loanAmount
  const approvedAt =
    application?.reviewedAt || application?.updatedAt || profile?.updatedAt

  return (
    <div className="mb-6 overflow-hidden rounded-2xl border border-emerald-200 bg-gradient-to-r from-emerald-50 to-white">
      <div className="flex flex-col gap-4 p-5 sm:flex-row sm:items-center sm:justify-between sm:p-6">
        <div className="flex items-start gap-4">
          <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-emerald-600 text-white">
            <svg
              className="h-6 w-6"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              viewBox="0 0 24 24"
              aria-hidden
            >
              <path strokeLinecap="round" strokeLinejoin="round" d="m5 13 4 4L19 7" />
            </svg>
          </span>
          <div>
            <p className="text-xs font-semibold uppercase tracking-[0.14em] text-emerald-700">
              Loan approved
            </p>
            <h2 className="mt-1 text-xl font-semibold text-emerald-950 sm:text-2xl">
              Your loan is approved
            </h2>
            <p className="mt-2 max-w-xl text-sm leading-relaxed text-emerald-900/80">
              All your documents and application details have been verified and approved by our
              admin team.
            </p>
            {loanAmount ? (
              <p className="mt-3 text-sm font-semibold text-emerald-900">
                Approved amount: {formatCurrency(loanAmount)}
              </p>
            ) : null}
            {approvedAt ? (
              <p className="mt-1 text-xs text-emerald-800/70">
                Approved on {formatDate(approvedAt)}
              </p>
            ) : null}
          </div>
        </div>
        <div className="rounded-xl border border-emerald-200 bg-white px-4 py-3 text-sm text-emerald-900">
          <p className="font-medium">What&apos;s next?</p>
          <p className="mt-1 text-emerald-800/75">
            Your loan will be processed for disbursal. We&apos;ll notify you here when it&apos;s
            ready.
          </p>
        </div>
      </div>
    </div>
  )
}

function StatusPill({ status }) {
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded border px-2 py-0.5 text-[11px] font-medium uppercase tracking-wide ${getStatusStyles(
        status,
      )}`}
    >
      <span className={`h-1.5 w-1.5 rounded-full ${getStatusDot(status)}`} />
      {formatStatus(status)}
    </span>
  )
}

function VerificationItem({ label, value, status, updatedAt, kind }) {
  return (
    <div className="border border-slate-200 bg-white px-4 py-3">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div className="min-w-0 flex-1">
          <p className="text-[11px] font-medium uppercase tracking-wide text-slate-500">
            {kind === 'document' ? 'Document' : 'Detail'} · {label}
          </p>
          <p className="mt-1 break-words text-sm text-slate-900">{value || '—'}</p>
        </div>
        <StatusPill status={status || 'pending'} />
      </div>
      <p className="mt-2 text-xs text-slate-400">Last reviewed: {formatDate(updatedAt)}</p>
    </div>
  )
}

function buildVerificationList(application) {
  const fieldStatuses = application?.verifications?.fields || {}
  const docStatuses = application?.verifications?.documents || {}
  const documents = application?.documents || {}

  const fields = FIELD_ITEMS.map((field) => {
    const verification = fieldStatuses[field.key] || { status: 'pending', updatedAt: null }
    return {
      id: `field:${field.key}`,
      kind: 'field',
      label: field.label,
      value: getFieldDisplayValue(application, field.key),
      status: verification.status || 'pending',
      updatedAt: verification.updatedAt,
    }
  })

  const docs = Object.entries(documents).map(([key, doc]) => {
    const verification = docStatuses[key] || { status: 'pending', updatedAt: null }
    return {
      id: `document:${key}`,
      kind: 'document',
      label: DOC_LABELS[key] || key,
      value: doc.originalName || doc.fileName || 'Uploaded file',
      status: verification.status || 'pending',
      updatedAt: verification.updatedAt,
    }
  })

  return [...fields, ...docs]
}

function isPendingApplication(app) {
  return app?.status !== 'verified' && app?.status !== 'rejected'
}

function ApplicationCard({ application, onOpen }) {
  const counts = application.counts || { accepted: 0, rejected: 0, pending: 0 }

  return (
    <button
      type="button"
      onClick={() => onOpen(application.id)}
      className="w-full border border-slate-200 bg-white p-5 text-left transition hover:border-slate-400"
    >
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <p className="text-base font-semibold text-slate-900">
            Loan application · {formatCurrency(application.loanAmount)}
          </p>
          <p className="mt-1 text-sm text-slate-500">{application.id}</p>
          <p className="mt-1 text-sm text-slate-600">
            Purpose:{' '}
            {LOAN_PURPOSE_LABELS[application.loanPurpose] || application.loanPurpose || '—'}
          </p>
          <p className="mt-1 text-xs text-slate-400">
            Submitted: {formatDate(application.submittedAt)} · Updated:{' '}
            {formatDate(application.updatedAt || application.reviewedAt)}
          </p>
        </div>
        <StatusPill status={application.status || 'submitted'} />
      </div>

      <div className="mt-4 grid grid-cols-3 gap-px border border-slate-200 bg-slate-200 text-center">
        <div className="bg-emerald-50 px-2 py-3">
          <p className="text-[11px] uppercase tracking-wide text-emerald-700">Accepted</p>
          <p className="mt-1 text-lg font-semibold text-emerald-900">{counts.accepted}</p>
        </div>
        <div className="bg-white px-2 py-3">
          <p className="text-[11px] uppercase tracking-wide text-slate-500">Pending</p>
          <p className="mt-1 text-lg font-semibold text-slate-900">{counts.pending}</p>
        </div>
        <div className="bg-rose-50 px-2 py-3">
          <p className="text-[11px] uppercase tracking-wide text-rose-700">Rejected</p>
          <p className="mt-1 text-lg font-semibold text-rose-900">{counts.rejected}</p>
        </div>
      </div>

      <p className="mt-4 text-sm font-medium text-slate-800">View verification status →</p>
    </button>
  )
}

function ApplicationDetail({ application, userToken, onApplicationUpdate, onBack }) {
  const [activeTab, setActiveTab] = useState('all')
  const [cibilLoading, setCibilLoading] = useState(false)
  const [cibilError, setCibilError] = useState('')
  const items = useMemo(() => buildVerificationList(application), [application])

  const acceptedItems = items.filter((item) => item.status === 'accepted')
  const rejectedItems = items.filter((item) => item.status === 'rejected')
  const pendingItems = items.filter(
    (item) => item.status !== 'accepted' && item.status !== 'rejected',
  )

  const visibleItems =
    activeTab === 'accepted'
      ? acceptedItems
      : activeTab === 'rejected'
        ? rejectedItems
        : activeTab === 'pending'
          ? pendingItems
          : items

  const tabCounts = {
    all: items.length,
    accepted: acceptedItems.length,
    rejected: rejectedItems.length,
    pending: pendingItems.length,
  }

  const cibil = application?.cibilReport || {}
  const canCheckCibil = Boolean(application?.canCheckCibil)

  async function handleCheckCibil() {
    if (!userToken) return
    setCibilLoading(true)
    setCibilError('')
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
        onApplicationUpdate?.({
          ...application,
          cibilReport: data.data?.cibilReport || cibil,
          canCheckCibil: true,
        })
      } else {
        setCibilError(data.message || 'Could not fetch CIBIL report.')
      }
    } catch {
      setCibilError('Could not reach the server. Please try again.')
    } finally {
      setCibilLoading(false)
    }
  }

  return (
    <div className="space-y-6">
      <button
        type="button"
        onClick={onBack}
        className="text-sm font-medium text-[var(--navy)] hover:underline"
      >
        ← Back to applications
      </button>

      <div className="rounded-none border border-slate-200 bg-white p-5">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h2 className="text-xl font-semibold text-slate-900">
              {formatCurrency(application.loanAmount)} loan application
            </h2>
            <p className="mt-1 text-sm text-slate-500">{application.id}</p>
            <p className="mt-2 text-sm text-slate-600">
              Submitted {formatDate(application.submittedAt)}
            </p>
            {application.status === 'verified' ? (
              <p className="mt-3 inline-flex items-center gap-1.5 rounded-full bg-emerald-100 px-3 py-1 text-xs font-semibold text-emerald-800">
                All documents and details approved
              </p>
            ) : null}
          </div>
          <StatusPill status={application.status || 'submitted'} />
        </div>
      </div>

      {canCheckCibil ? (
        <div className="rounded-none border border-slate-200 bg-white p-5 space-y-3">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <h3 className="text-base font-semibold text-slate-900">CIBIL report</h3>
              <p className="mt-1 text-sm text-slate-500">
                Available after login while your loan application is in progress.
              </p>
            </div>
            <button
              type="button"
              disabled={cibilLoading}
              onClick={handleCheckCibil}
              className="border border-slate-900 bg-slate-900 px-3 py-1.5 text-xs font-semibold text-white hover:bg-black disabled:opacity-60"
            >
              {cibilLoading ? 'Checking…' : cibil.status === 'ready' ? 'Refresh CIBIL' : 'Check CIBIL'}
            </button>
          </div>
          <div className="grid gap-3 sm:grid-cols-3">
            <div className="border border-slate-200 px-3 py-2">
              <p className="text-[11px] uppercase tracking-wide text-slate-500">Status</p>
              <p className="mt-1 text-sm font-semibold text-slate-900">{cibil.status || 'idle'}</p>
            </div>
            <div className="border border-slate-200 px-3 py-2">
              <p className="text-[11px] uppercase tracking-wide text-slate-500">Score</p>
              <p className="mt-1 text-sm font-semibold text-slate-900">
                {cibil.score ?? cibil.summary?.score ?? '—'}
              </p>
            </div>
            <div className="border border-slate-200 px-3 py-2">
              <p className="text-[11px] uppercase tracking-wide text-slate-500">Updated</p>
              <p className="mt-1 text-sm font-semibold text-slate-900">
                {cibil.updatedAt ? formatDate(cibil.updatedAt) : '—'}
              </p>
            </div>
          </div>
          {cibil.error ? <p className="text-sm text-rose-600">{cibil.error}</p> : null}
          {cibilError ? <p className="text-sm text-rose-600">{cibilError}</p> : null}
          {cibil.status === 'pending' ? (
            <p className="text-sm text-slate-500">Report requested. Refresh shortly if score is empty.</p>
          ) : null}
        </div>
      ) : null}

      <div className="flex gap-2 overflow-x-auto border-b border-slate-200 pb-0">
        {DETAIL_TABS.map((tab) => {
          const active = activeTab === tab.id
          return (
            <button
              key={tab.id}
              type="button"
              onClick={() => setActiveTab(tab.id)}
              className={`shrink-0 border-b-2 px-3 py-2 text-sm font-medium transition ${
                active
                  ? 'border-slate-900 text-slate-900'
                  : 'border-transparent text-slate-500 hover:text-slate-800'
              }`}
            >
              {tab.label}
              <span className="ml-2 text-xs text-slate-400">{tabCounts[tab.id]}</span>
            </button>
          )
        })}
      </div>

      <div className="grid gap-3 sm:grid-cols-2">
        {visibleItems.length === 0 ? (
          <p className="text-sm text-slate-500 sm:col-span-2">
            No {activeTab === 'all' ? '' : `${activeTab} `}items for this application.
          </p>
        ) : (
          visibleItems.map((item) => (
            <VerificationItem
              key={item.id}
              label={item.label}
              value={item.value}
              status={item.status}
              updatedAt={item.updatedAt}
              kind={item.kind}
            />
          ))
        )}
      </div>
    </div>
  )
}

function UserProfilePage({
  profile: initialProfile,
  userToken,
  onLogout,
  onBackHome,
  onProfileRefresh,
}) {
  const [profile, setProfile] = useState(initialProfile)
  const [refreshing, setRefreshing] = useState(false)
  const [selectedId, setSelectedId] = useState(null)
  const [listFilter, setListFilter] = useState('pending')

  useEffect(() => {
    setProfile(initialProfile)
  }, [initialProfile])

  useEffect(() => {
    if (!userToken) return undefined

    let cancelled = false

    async function refresh() {
      try {
        const response = await fetch(`${API_BASE}/api/user/profile`, {
          headers: { Authorization: `Bearer ${userToken}` },
        })
        const data = await response.json()
        if (!cancelled && response.ok && data.success) {
          setProfile(data.data)
          onProfileRefresh?.(data.data)
        }
      } catch {
        // Keep current profile if refresh fails
      }
    }

    refresh()
    const intervalId = setInterval(refresh, 15000)
    return () => {
      cancelled = true
      clearInterval(intervalId)
    }
  }, [userToken, onProfileRefresh])

  async function handleRefresh() {
    if (!userToken || refreshing) return
    setRefreshing(true)
    try {
      const response = await fetch(`${API_BASE}/api/user/profile`, {
        headers: { Authorization: `Bearer ${userToken}` },
      })
      const data = await response.json()
      if (response.ok && data.success) {
        setProfile(data.data)
        onProfileRefresh?.(data.data)
      }
    } catch {
      // ignore
    } finally {
      setRefreshing(false)
    }
  }

  const applications = profile?.applications?.length
    ? profile.applications
    : profile?.application
      ? [profile.application]
      : []

  const pendingApplications = applications.filter(isPendingApplication)
  const completedApplications = applications.filter((app) => !isPendingApplication(app))

  const listedApplications =
    listFilter === 'pending'
      ? pendingApplications
      : listFilter === 'completed'
        ? completedApplications
        : applications

  const selectedApplication =
    applications.find((item) => item.id === selectedId) || null

  const approvedApplication = useMemo(() => {
    if (profile?.application && isLoanFullyApproved({ ...profile, application: profile.application })) {
      return profile.application
    }
    return applications.find((app) => isLoanFullyApproved({ ...profile, application: app })) || null
  }, [profile, applications])

  const showApprovedBanner = isLoanFullyApproved(profile) || Boolean(approvedApplication)

  return (
    <div className="mx-auto max-w-6xl px-4 py-6 sm:px-6 lg:py-8">
      <div className="mb-6 flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="text-sm font-medium text-[var(--gold)]">My Profile</p>
          <h1 className="mt-1 text-3xl font-semibold text-slate-900">
            {profile?.fullName || 'Your applications'}
          </h1>
          <p className="mt-2 text-sm text-slate-600">
            +91 {profile?.mobile || '—'} · Review your loan applications and admin verification
            updates.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            onClick={handleRefresh}
            disabled={refreshing}
            className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50 disabled:opacity-60"
          >
            {refreshing ? 'Refreshing...' : 'Refresh status'}
          </button>
          <button
            type="button"
            onClick={onBackHome}
            className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm font-medium text-slate-700 hover:bg-slate-50"
          >
            Home
          </button>
          <button
            type="button"
            onClick={onLogout}
            className="rounded-lg bg-[var(--navy)] px-3 py-2 text-sm font-medium text-white hover:bg-black"
          >
            Sign Out
          </button>
        </div>
      </div>

      {showApprovedBanner ? (
        <LoanApprovedBanner application={approvedApplication} profile={profile} />
      ) : null}

      {selectedApplication ? (
        <ApplicationDetail
          application={{
            ...selectedApplication,
            canCheckCibil:
              selectedApplication.canCheckCibil ??
              (profile?.canCheckCibil && selectedApplication.id === profile?.application?.id),
          }}
          userToken={userToken}
          onApplicationUpdate={(nextApp) => {
            setProfile((prev) => {
              if (!prev) return prev
              const applications = Array.isArray(prev.applications)
                ? prev.applications.map((item) =>
                    item.id === nextApp.id ? { ...item, ...nextApp } : item,
                  )
                : [nextApp]
              return {
                ...prev,
                applications,
                application:
                  prev.application?.id === nextApp.id
                    ? { ...prev.application, ...nextApp }
                    : prev.application,
                cibilReport: nextApp.cibilReport || prev.cibilReport,
              }
            })
          }}
          onBack={() => setSelectedId(null)}
        />
      ) : (
        <div className="space-y-5">
          <div className="flex flex-wrap gap-2">
            {[
              { id: 'pending', label: 'Pending applications', count: pendingApplications.length },
              { id: 'completed', label: 'Completed', count: completedApplications.length },
              { id: 'all', label: 'All applications', count: applications.length },
            ].map((filter) => {
              const active = listFilter === filter.id
              return (
                <button
                  key={filter.id}
                  type="button"
                  onClick={() => setListFilter(filter.id)}
                  className={`rounded-full px-4 py-2 text-sm font-semibold ${
                    active
                      ? 'bg-[var(--navy)] text-white'
                      : 'bg-white text-slate-600 ring-1 ring-slate-200'
                  }`}
                >
                  {filter.label}
                  <span className="ml-2 rounded-full bg-white/20 px-2 py-0.5 text-xs">
                    {filter.count}
                  </span>
                </button>
              )
            })}
          </div>

          {listedApplications.length === 0 ? (
            <div className="rounded-2xl border border-dashed border-slate-300 bg-white px-6 py-12 text-center">
              <p className="text-sm text-slate-500">
                {listFilter === 'pending'
                  ? 'No pending applications right now.'
                  : 'No applications found yet.'}
              </p>
            </div>
          ) : (
            <div className="space-y-3">
              {listedApplications.map((application) => (
                <ApplicationCard
                  key={application.id}
                  application={application}
                  onOpen={setSelectedId}
                />
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  )
}

export default UserProfilePage
