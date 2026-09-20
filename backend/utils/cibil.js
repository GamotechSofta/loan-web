export const CIBIL_CONSENT_TEXT =
  'We confirm and undertake that valid end-user consent has been obtained for fetching CIBIL REPORT using MOBILE NUMBER, and that such consent remains active and unrevoked at the time of this request.'

export const CIBIL_ACTIVE_STATUSES = new Set(['submitted', 'in_review', 'verified'])

export function emptyCibilReport() {
  return {
    status: 'idle',
    requestedAt: null,
    updatedAt: null,
    requestId: null,
    score: null,
    summary: null,
    report: null,
    providerResponse: null,
    error: null,
  }
}

export function isLoanApplicationActive(submission, user) {
  if (!submission) return false
  if (user?.loanStatus === 'disbursed') return false
  const status = String(submission.status || '').toLowerCase()
  return CIBIL_ACTIVE_STATUSES.has(status)
}

export function extractCibilScore(payload) {
  if (!payload || typeof payload !== 'object') return null

  const candidates = [
    payload.score,
    payload.Score,
    payload.cibilScore,
    payload.CibilScore,
    payload.credit_score,
    payload.creditScore,
    payload?.data?.score,
    payload?.data?.Score,
    payload?.data?.cibilScore,
    payload?.data?.credit_score,
    payload?.data?.creditScore,
    payload?.result?.score,
    payload?.result?.Score,
    payload?.report?.score,
    payload?.Report?.Score,
  ]

  for (const value of candidates) {
    const num = Number(value)
    if (Number.isFinite(num) && num > 0) return num
  }

  return null
}

export function summarizeCibilPayload(payload) {
  if (!payload || typeof payload !== 'object') return null

  const score = extractCibilScore(payload)
  const name =
    payload.name ||
    payload.Full_Name ||
    payload.full_name ||
    payload?.data?.name ||
    payload?.data?.Full_Name ||
    null
  const pan =
    payload.pan ||
    payload.PAN_Number ||
    payload.pan_number ||
    payload?.data?.pan ||
    payload?.data?.PAN_Number ||
    null
  const status =
    payload.status ||
    payload.Status ||
    payload?.data?.status ||
    payload?.data?.Status ||
    null

  return {
    score,
    name: name ? String(name) : null,
    pan: pan ? String(pan) : null,
    status: status ? String(status) : null,
  }
}

export function toPublicCibilReport(report) {
  if (!report || typeof report !== 'object') return emptyCibilReport()
  return {
    status: report.status || 'idle',
    requestedAt: report.requestedAt || null,
    updatedAt: report.updatedAt || null,
    requestId: report.requestId || null,
    score: report.score ?? extractCibilScore(report.report || report.providerResponse),
    summary: report.summary || summarizeCibilPayload(report.report || report.providerResponse),
    report: report.report || null,
    error: report.error || null,
  }
}
