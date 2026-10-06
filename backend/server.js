import fs from 'fs'
import path from 'path'
import crypto from 'crypto'
import { fileURLToPath } from 'url'
import express from 'express'
import cors from 'cors'
import axios from 'axios'
import dotenv from 'dotenv'
import multer from 'multer'
import jwt from 'jsonwebtoken'
import {
  getAadhaarError,
  getPanError,
  sanitizeAadhaar,
  sanitizePan,
} from './utils/idValidation.js'
import {
  CIBIL_CONSENT_TEXT,
  emptyCibilReport,
  extractCibilScore,
  isLoanApplicationActive,
  summarizeCibilPayload,
  toPublicCibilReport,
} from './utils/cibil.js'

dotenv.config()

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const app = express()

app.use(cors())
app.use(express.json())

const uploadsDir = path.join(__dirname, 'uploads')
const dataDir = path.join(__dirname, 'data')
const submissionsFile = path.join(dataDir, 'kyc-submissions.json')
const usersFile = path.join(dataDir, 'users.json')

fs.mkdirSync(uploadsDir, { recursive: true })
fs.mkdirSync(dataDir, { recursive: true })

if (!fs.existsSync(submissionsFile)) {
  fs.writeFileSync(submissionsFile, '[]')
}

if (!fs.existsSync(usersFile)) {
  fs.writeFileSync(usersFile, '[]')
}

const {
  MSG91_AUTH_KEY,
  MSG91_TEMPLATE_ID,
  MSG91_SENDER_ID,
  MSG91_BASE_URL = 'https://control.msg91.com/api/v5',
  MSG91_USE_SENDER = 'false',
  PORT = 5000,
  ADMIN_USERNAME = 'admin',
  ADMIN_PASSWORD = 'admin123',
  JWT_SECRET = 'sakaar-microcredit-admin-jwt-secret-change-me',
  API_KEY,
  TRUDETAILS_API_KEY,
  PUBLIC_BASE_URL = '',
  CIBIL_CALLBACK_URL = '',
} = process.env

const TRUDETAILS_KEY = String(TRUDETAILS_API_KEY || API_KEY || '').trim()
const TRUDETAILS_CIBIL_URL = 'https://trudetails.com/enrich/v2/get-cibil-report'

const useSender = MSG91_USE_SENDER === 'true'
/** MSG91 OTP digit length — must match UI (6 boxes) and DLT template. */
const MSG91_OTP_LENGTH = Number(process.env.MSG91_OTP_LENGTH) || 6
/** OTP validity window in minutes for send + verify. */
const MSG91_OTP_EXPIRY_MINUTES = 10

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadsDir),
  filename: (_req, file, cb) => {
    const unique = `${Date.now()}-${Math.round(Math.random() * 1e9)}`
    cb(null, `${unique}-${file.originalname.replace(/\s+/g, '_')}`)
  },
})

const upload = multer({ storage })

function readSubmissions() {
  try {
    return JSON.parse(fs.readFileSync(submissionsFile, 'utf8'))
  } catch {
    return []
  }
}

function writeSubmissions(submissions) {
  fs.writeFileSync(submissionsFile, JSON.stringify(submissions, null, 2))
}

function readUsers() {
  try {
    return JSON.parse(fs.readFileSync(usersFile, 'utf8'))
  } catch {
    return []
  }
}

function writeUsers(users) {
  fs.writeFileSync(usersFile, JSON.stringify(users, null, 2))
}

function upsertUserProfile(profileData) {
  const users = readUsers()
  const existingIndex = users.findIndex((user) => user.mobile === profileData.mobile)
  const now = new Date().toISOString()

  if (existingIndex >= 0) {
    users[existingIndex] = {
      ...users[existingIndex],
      ...profileData,
      updatedAt: now,
    }
    writeUsers(users)
    return users[existingIndex]
  }

  const user = {
    id: `USR-${Date.now()}`,
    createdAt: now,
    updatedAt: now,
    ...profileData,
  }
  users.unshift(user)
  writeUsers(users)
  return user
}

function getUserByMobile(mobile) {
  return readUsers().find((user) => user.mobile === mobile)
}

function getLatestSubmissionByMobile(mobile) {
  return readSubmissions().find((item) => item.mobile === mobile) || null
}

function resolveUserAccount(mobile) {
  const existing = getUserByMobile(mobile)
  if (existing) return existing

  const submission = getLatestSubmissionByMobile(mobile)
  if (!submission) return null

  return upsertUserProfile({
    mobile: submission.mobile,
    fullName: submission.fullName || '',
    aadhaar: submission.aadhaar || '',
    pan: submission.pan || '',
    address: submission.address || '',
    employment: submission.employment || '',
    income: submission.income || '',
    accountNumber: submission.accountNumber || '',
    ifsc: submission.ifsc || '',
    pinCode: submission.pinCode || '',
    loanPurpose: submission.loanPurpose || '',
    loanAmount: submission.loanAmount || 0,
    processingFee: submission.processingFee || 0,
    emi: submission.emi || 0,
    totalPayable: submission.totalPayable || 0,
    netCreditedAmount: submission.netCreditedAmount || 0,
    offerValidUntil: submission.offerValidUntil || '',
    eSignConsent: Boolean(submission.eSignConsent),
    documents: submission.documents || {},
    kycStatus: submission.status === 'verified' ? 'verified' : submission.status || 'submitted',
    loanStatus: submission.status === 'verified' ? 'disbursed' : 'pending_disbursal',
    disbursedAmount: submission.status === 'verified' ? submission.netCreditedAmount || 0 : 0,
    kycId: submission.id,
  })
}

function issueUserToken(user) {
  return jwt.sign(
    { role: 'user', mobile: user.mobile, userId: user.id },
    JWT_SECRET,
    { expiresIn: '7d' },
  )
}

function isRecordVerified(submission, user) {
  if (submission?.status === 'verified') return true
  if (user?.kycStatus === 'verified') return true
  if (user?.loanStatus === 'disbursed') return true
  return false
}

function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex')
  const hash = crypto.scryptSync(String(password), salt, 64).toString('hex')
  return `${salt}:${hash}`
}

function verifyPassword(password, storedHash) {
  if (!storedHash || typeof storedHash !== 'string' || !storedHash.includes(':')) {
    return false
  }
  const [salt, expectedHash] = storedHash.split(':')
  if (!salt || !expectedHash) return false
  const actualHash = crypto.scryptSync(String(password), salt, 64).toString('hex')
  try {
    return crypto.timingSafeEqual(Buffer.from(expectedHash, 'hex'), Buffer.from(actualHash, 'hex'))
  } catch {
    return false
  }
}

function toSafeUser(user) {
  if (!user || typeof user !== 'object') return user
  const safeUser = { ...user }
  delete safeUser.passwordHash
  return safeUser
}

function buildVerificationState(submission) {
  const fieldKeys = [
    'fullName',
    'parentName',
    'dateOfBirth',
    'gender',
    'mobile',
    'email',
    'residentialAddress',
    'permanentAddress',
    'occupation',
    'employerDetails',
    'incomeDetails',
    'educationalInfo',
    'nomineeName',
    'nomineeRelation',
    'nomineeMobile',
    'emergencyContactName',
    'emergencyContactRelation',
    'emergencyContactMobile',
    'reference1Name',
    'reference1Mobile',
    'reference2Name',
    'reference2Mobile',
    'username',
    'customerFeedback',
    'communicationPreferences',
    'aadhaar',
    'pan',
    'accountNumber',
    'ifsc',
    'pinCode',
    'loanPurpose',
    'loanAmount',
    'eSignConsent',
  ]

  const existing = submission.verifications || { fields: {}, documents: {} }
  const fields = {}
  const documents = {}

  fieldKeys.forEach((key) => {
    fields[key] = existing.fields?.[key] || {
      status: 'pending',
      updatedAt: null,
    }
  })

  Object.keys(submission.documents || {}).forEach((key) => {
    documents[key] = existing.documents?.[key] || {
      status: 'pending',
      updatedAt: null,
    }
  })

  return { fields, documents }
}

function computeOverallStatus(verifications) {
  const allItems = [
    ...Object.values(verifications.fields || {}),
    ...Object.values(verifications.documents || {}),
  ]

  if (allItems.length === 0) return 'submitted'
  if (allItems.some((item) => item.status === 'rejected')) return 'rejected'
  if (allItems.every((item) => item.status === 'accepted')) return 'verified'
  if (allItems.some((item) => item.status === 'accepted')) return 'in_review'
  return 'submitted'
}

function normalizeSubmission(submission) {
  const verifications = buildVerificationState(submission)
  const reviewItems = [
    ...Object.values(verifications.fields || {}),
    ...Object.values(verifications.documents || {}),
  ]
  // Older app builds could call the completion endpoint immediately after
  // submission, setting only the overall status to verified while every admin
  // review item remained pending. Treat those records as submitted so they
  // enter the real admin queue instead of appearing falsely approved.
  const wasSelfCompleted =
    submission.status === 'verified' &&
    !submission.reviewedAt &&
    reviewItems.length > 0 &&
    reviewItems.every((item) => item.status === 'pending')

  return {
    ...submission,
    verifications,
    status: wasSelfCompleted ? 'submitted' : submission.status,
    updatedAt: submission.updatedAt || submission.reviewedAt || submission.submittedAt,
  }
}

function buildAdminStats() {
  const users = readUsers()
  const submissions = readSubmissions()

  let verified = 0
  let notVerified = 0
  let pendingKyc = 0
  let disbursedLoans = 0

  submissions.forEach((submission) => {
    const user = getUserByMobile(submission.mobile)
    if (isRecordVerified(submission, user)) {
      verified += 1
    } else {
      notVerified += 1
    }
    if (submission.status === 'submitted' || submission.status === 'in_review') {
      pendingKyc += 1
    }
  })

  users.forEach((user) => {
    if (user.loanStatus === 'disbursed') disbursedLoans += 1
  })

  const totalUsers = users.length || new Set(submissions.map((item) => item.mobile)).size
  const totalDocuments = submissions.reduce(
    (count, submission) => count + Object.keys(submission.documents || {}).length,
    0,
  )
  const eSignConsents = submissions.filter((submission) => submission.eSignConsent).length

  return {
    totalUsers,
    totalSubmissions: submissions.length,
    verified,
    notVerified,
    pendingKyc,
    disbursedLoans,
    totalDocuments,
    eSignConsents,
    latestSubmissionAt: submissions[0]?.submittedAt || null,
  }
}

function normalizeIndianMobile(mobile) {
  const digits = String(mobile || '').replace(/\D/g, '')
  if (digits.length === 10) return digits
  if (digits.length === 12 && digits.startsWith('91')) return digits.slice(2)
  return null
}

function validateMsg91Config() {
  if (!MSG91_AUTH_KEY || !MSG91_TEMPLATE_ID) {
    return 'Missing MSG91_AUTH_KEY or MSG91_TEMPLATE_ID in environment.'
  }
  return null
}

function isMsg91OtpSuccess(data) {
  if (!data || typeof data !== 'object') return false
  const type = String(data.type || '').toLowerCase()
  // Strict: MSG91 must return type "success". Never treat ambiguous payloads as verified.
  if (type !== 'success') return false
  const message = String(data.message || '').toLowerCase()
  if (
    message.includes('not match') ||
    message.includes('invalid') ||
    message.includes('expired') ||
    message.includes('already verified') ||
    message.includes('no otp')
  ) {
    return false
  }
  return true
}

function normalizeOtpCode(otp) {
  const digits = String(otp || '').replace(/\D/g, '')
  if (digits.length !== MSG91_OTP_LENGTH) return null
  return digits
}

/** Pending OTP challenges: mobile -> { requestId, sentAt, attempts } */
const pendingOtpChallenges = new Map()

function rememberOtpChallenge(mobile, requestId) {
  pendingOtpChallenges.set(mobile, {
    requestId: requestId || null,
    sentAt: Date.now(),
    attempts: 0,
  })
}

function getActiveOtpChallenge(mobile) {
  const challenge = pendingOtpChallenges.get(mobile)
  if (!challenge) return null
  const maxAgeMs = MSG91_OTP_EXPIRY_MINUTES * 60 * 1000
  if (Date.now() - challenge.sentAt > maxAgeMs) {
    pendingOtpChallenges.delete(mobile)
    return null
  }
  return challenge
}

function clearOtpChallenge(mobile) {
  pendingOtpChallenges.delete(mobile)
}

function safeEqual(a, b) {
  const left = Buffer.from(String(a))
  const right = Buffer.from(String(b))
  if (left.length !== right.length) return false
  return crypto.timingSafeEqual(left, right)
}

function getTokenFromRequest(req) {
  const authHeader = req.headers.authorization || ''
  if (authHeader.startsWith('Bearer ')) {
    return authHeader.slice(7).trim()
  }
  if (req.query?.token) {
    return String(req.query.token)
  }
  return null
}

function requireAdminAuth(req, res, next) {
  const token = getTokenFromRequest(req)
  if (!token) {
    return res.status(401).json({ success: false, message: 'Authentication required.' })
  }

  try {
    const payload = jwt.verify(token, JWT_SECRET)
    if (payload?.role !== 'admin') {
      return res.status(403).json({ success: false, message: 'Admin access required.' })
    }
    req.admin = payload
    return next()
  } catch {
    return res.status(401).json({ success: false, message: 'Invalid or expired token.' })
  }
}

function requireUserAuth(req, res, next) {
  const token = getTokenFromRequest(req)
  if (!token) {
    return res.status(401).json({ success: false, message: 'Authentication required.' })
  }

  try {
    const payload = jwt.verify(token, JWT_SECRET)
    if (payload?.role !== 'user' || !payload?.mobile) {
      return res.status(403).json({ success: false, message: 'User access required.' })
    }
    req.user = payload
    return next()
  } catch {
    return res.status(401).json({ success: false, message: 'Invalid or expired token.' })
  }
}

function resolveCibilCallbackUrl() {
  if (CIBIL_CALLBACK_URL) return String(CIBIL_CALLBACK_URL).trim()
  if (PUBLIC_BASE_URL) {
    return `${String(PUBLIC_BASE_URL).replace(/\/$/, '')}/api/cibil/callback`
  }
  return 'https://example.com/report-path'
}

function validateTrudetailsConfig() {
  if (!TRUDETAILS_KEY) {
    return 'Missing TruDetails API key. Set API_KEY or TRUDETAILS_API_KEY in environment.'
  }
  return null
}

function findActiveApplicationForMobile(mobile) {
  const submissions = readSubmissions()
  const matches = submissions.filter((item) => item.mobile === mobile)
  if (matches.length === 0) return null

  const user = getUserByMobile(mobile)
  const active = matches.find((item) => isLoanApplicationActive(item, user))
  return active || null
}

function getSubmissionById(submissionId) {
  return readSubmissions().find((item) => item.id === submissionId) || null
}

function updateSubmissionCibil(submissionId, cibilPatch) {
  const submissions = readSubmissions()
  const index = submissions.findIndex((item) => item.id === submissionId)
  if (index < 0) return null

  const now = new Date().toISOString()
  const current = submissions[index].cibilReport || emptyCibilReport()
  const nextReport = {
    ...current,
    ...cibilPatch,
    updatedAt: now,
  }
  if (nextReport.report || nextReport.providerResponse) {
    nextReport.score =
      extractCibilScore(nextReport.report) ||
      extractCibilScore(nextReport.providerResponse) ||
      nextReport.score ||
      null
    nextReport.summary =
      summarizeCibilPayload(nextReport.report || nextReport.providerResponse) ||
      nextReport.summary
  }

  submissions[index] = {
    ...submissions[index],
    cibilReport: nextReport,
    updatedAt: now,
  }
  writeSubmissions(submissions)

  const users = readUsers()
  const userIndex = users.findIndex((item) => item.mobile === submissions[index].mobile)
  if (userIndex >= 0) {
    users[userIndex] = {
      ...users[userIndex],
      cibilReport: toPublicCibilReport(nextReport),
      updatedAt: now,
    }
    writeUsers(users)
  }

  return submissions[index]
}

function matchSubmissionFromCibilCallback(payload) {
  if (!payload || typeof payload !== 'object') return null

  const requestId =
    payload.request_id ||
    payload.requestId ||
    payload.RequestId ||
    payload?.data?.request_id ||
    payload?.data?.requestId ||
    null
  const mobile = normalizeIndianMobile(
    payload.Mobile_Number ||
      payload.mobile ||
      payload.mobile_number ||
      payload?.data?.Mobile_Number ||
      payload?.data?.mobile ||
      payload?.data?.mobile_number,
  )
  const pan = sanitizePan(
    payload.PAN_Number || payload.pan || payload.pan_number || payload?.data?.PAN_Number || payload?.data?.pan,
  )

  const submissions = readSubmissions()
  if (requestId) {
    const byRequest = submissions.find(
      (item) => item.cibilReport?.requestId && String(item.cibilReport.requestId) === String(requestId),
    )
    if (byRequest) return byRequest
  }
  if (mobile) {
    const pending = submissions.find(
      (item) =>
        item.mobile === mobile &&
        (item.cibilReport?.status === 'pending' || item.cibilReport?.status === 'requested'),
    )
    if (pending) return pending
    const latest = submissions.find((item) => item.mobile === mobile)
    if (latest) return latest
  }
  if (pan) {
    const byPan = submissions.find(
      (item) => sanitizePan(item.pan) === pan && item.cibilReport?.status === 'pending',
    )
    if (byPan) return byPan
  }
  return null
}

async function fetchCibilFromTrudetails({ mobile, pan, fullName }) {
  const callbackUrl = resolveCibilCallbackUrl()
  const response = await axios.post(
    TRUDETAILS_CIBIL_URL,
    {
      Mobile_Number: mobile,
      PAN_Number: pan,
      Full_Name: fullName,
      Callback_Url: callbackUrl,
      Concent_Text: CIBIL_CONSENT_TEXT,
      Concent: 'Y',
    },
    {
      headers: {
        Authorization: TRUDETAILS_KEY,
        'Content-Type': 'application/json',
      },
      timeout: 45000,
    },
  )
  return response
}

async function requestCibilForSubmission(submission, { triggeredBy }) {
  const configError = validateTrudetailsConfig()
  if (configError) {
    return { ok: false, statusCode: 500, message: configError }
  }

  const mobile = normalizeIndianMobile(submission.mobile)
  const pan = sanitizePan(submission.pan)
  const fullName = String(submission.fullName || '').trim()
  const panError = getPanError(pan)

  if (!mobile) {
    return { ok: false, statusCode: 400, message: 'Valid mobile number is required for CIBIL.' }
  }
  if (panError) {
    return { ok: false, statusCode: 400, message: panError }
  }
  if (!fullName) {
    return { ok: false, statusCode: 400, message: 'Full name is required for CIBIL.' }
  }

  const now = new Date().toISOString()
  updateSubmissionCibil(submission.id, {
    status: 'pending',
    requestedAt: now,
    error: null,
    triggeredBy,
  })

  try {
    const response = await fetchCibilFromTrudetails({ mobile, pan, fullName })
    const providerData = response.data
    const requestId =
      providerData?.request_id ||
      providerData?.requestId ||
      providerData?.data?.request_id ||
      providerData?.data?.requestId ||
      null
    const immediateScore = extractCibilScore(providerData)
    const looksComplete = Boolean(immediateScore) || Boolean(providerData?.report || providerData?.data?.report)

    const updated = updateSubmissionCibil(submission.id, {
      status: looksComplete ? 'ready' : 'pending',
      requestId: requestId ? String(requestId) : null,
      providerResponse: providerData,
      report: looksComplete ? providerData?.report || providerData?.data || providerData : null,
      score: immediateScore,
      summary: summarizeCibilPayload(providerData),
      error: null,
      triggeredBy,
    })

    return {
      ok: true,
      statusCode: 200,
      message: looksComplete
        ? 'CIBIL report fetched successfully.'
        : 'CIBIL report requested. It will appear when the provider callback completes.',
      data: toPublicCibilReport(updated?.cibilReport),
    }
  } catch (error) {
    const apiError = error.response?.data || { message: error.message }
    const message =
      apiError?.message ||
      apiError?.error ||
      (typeof apiError === 'string' ? apiError : null) ||
      'Failed to fetch CIBIL report.'
    updateSubmissionCibil(submission.id, {
      status: 'failed',
      error: typeof message === 'string' ? message : 'Failed to fetch CIBIL report.',
      providerResponse: apiError,
      triggeredBy,
    })
    console.error('TruDetails CIBIL error:', apiError)
    return {
      ok: false,
      statusCode: error.response?.status && error.response.status < 600 ? error.response.status : 502,
      message: typeof message === 'string' ? message : 'Failed to fetch CIBIL report.',
      error: apiError,
    }
  }
}

app.get('/health', (_req, res) => {
  res.json({ ok: true, service: 'loan-backend' })
})

app.post('/api/admin/login', (req, res) => {
  const username = String(req.body?.username || '').trim()
  const password = String(req.body?.password || '')

  if (!username || !password) {
    return res.status(400).json({ success: false, message: 'Username and password are required.' })
  }

  const usernameOk = safeEqual(username, ADMIN_USERNAME)
  const passwordOk = safeEqual(password, ADMIN_PASSWORD)

  if (!usernameOk || !passwordOk) {
    return res.status(401).json({ success: false, message: 'Invalid username or password.' })
  }

  const token = jwt.sign({ role: 'admin', username: ADMIN_USERNAME }, JWT_SECRET, {
    expiresIn: '12h',
  })

  return res.json({
    success: true,
    message: 'Logged in successfully.',
    data: {
      token,
      username: ADMIN_USERNAME,
    },
  })
})

app.get('/api/admin/me', requireAdminAuth, (req, res) => {
  return res.json({
    success: true,
    data: {
      username: req.admin.username,
      role: req.admin.role,
    },
  })
})


async function sendOtpToMobile(normalizedMobile) {
  const params = {
    mobile: `91${normalizedMobile}`,
    template_id: MSG91_TEMPLATE_ID,
    otp_length: MSG91_OTP_LENGTH,
    otp_expiry: MSG91_OTP_EXPIRY_MINUTES,
  }

  if (useSender && MSG91_SENDER_ID) {
    params.sender = MSG91_SENDER_ID
  }

  return axios.post(
    `${MSG91_BASE_URL}/otp`,
    {},
    {
      params,
      headers: {
        authkey: MSG91_AUTH_KEY,
        'Content-Type': 'application/json',
      },
      timeout: 15000,
    },
  )
}

async function verifyOtpForMobile(normalizedMobile, otp) {
  return axios.get(`${MSG91_BASE_URL}/otp/verify`, {
    params: {
      mobile: `91${normalizedMobile}`,
      otp,
      otp_expiry: MSG91_OTP_EXPIRY_MINUTES,
    },
    headers: { authkey: MSG91_AUTH_KEY },
    timeout: 15000,
  })
}

async function handleSendOtpRequest(normalizedMobile, res) {
  const configError = validateMsg91Config()
  if (configError) {
    return res.status(500).json({ success: false, message: configError })
  }

  try {
    const response = await sendOtpToMobile(normalizedMobile)
    console.log('MSG91 send response:', response.data)

    if (!isMsg91OtpSuccess(response.data)) {
      return res.status(400).json({
        success: false,
        message: response.data?.message || 'Failed to send OTP.',
        data: response.data,
      })
    }

    rememberOtpChallenge(normalizedMobile, response.data?.request_id)
    return res.json({
      success: true,
      message: 'OTP sent successfully to your mobile number.',
      data: {
        mobile: normalizedMobile,
      },
    })
  } catch (error) {
    const statusCode = error.response?.status || 500
    const apiError = error.response?.data || { message: error.message }
    console.error('MSG91 send error:', apiError)
    return res.status(statusCode).json({
      success: false,
      message: apiError?.message || 'Failed to send OTP.',
      error: apiError,
    })
  }
}

async function handleVerifyOtpRequest(normalizedMobile, otp, res, { onVerified }) {
  const normalizedOtp = normalizeOtpCode(otp)
  if (!normalizedOtp) {
    return res.status(400).json({
      success: false,
      message: `Please enter the valid ${MSG91_OTP_LENGTH}-digit OTP sent to your mobile.`,
    })
  }

  const challenge = getActiveOtpChallenge(normalizedMobile)
  if (!challenge) {
    return res.status(400).json({
      success: false,
      message: 'Please request a new OTP first, then enter the code from the SMS.',
    })
  }

  if (challenge.attempts >= 5) {
    clearOtpChallenge(normalizedMobile)
    return res.status(429).json({
      success: false,
      message: 'Too many invalid OTP attempts. Please request a new OTP.',
    })
  }

  const configError = validateMsg91Config()
  if (configError) {
    return res.status(500).json({ success: false, message: configError })
  }

  try {
    const response = await verifyOtpForMobile(normalizedMobile, normalizedOtp)
    console.log('MSG91 verify response:', response.data)

    if (!isMsg91OtpSuccess(response.data)) {
      challenge.attempts += 1
      pendingOtpChallenges.set(normalizedMobile, challenge)
      return res.status(400).json({
        success: false,
        message: response.data?.message || 'Invalid OTP. Please try again.',
        data: response.data,
      })
    }

    clearOtpChallenge(normalizedMobile)
    return onVerified({ msg91: response.data })
  } catch (error) {
    challenge.attempts += 1
    pendingOtpChallenges.set(normalizedMobile, challenge)
    const statusCode = error.response?.status || 500
    const apiError = error.response?.data || { message: error.message }
    console.error('MSG91 verify error:', apiError)
    return res.status(statusCode >= 400 && statusCode < 600 ? 400 : statusCode).json({
      success: false,
      message: apiError?.message || 'Invalid OTP. Please try again.',
      error: apiError,
    })
  }
}

app.post('/api/otp/send', async (req, res) => {
  const normalizedMobile = normalizeIndianMobile(req.body?.mobile)
  if (!normalizedMobile) {
    return res
      .status(400)
      .json({ success: false, message: 'Please provide a valid 10 digit mobile number.' })
  }

  return handleSendOtpRequest(normalizedMobile, res)
})

app.post('/api/otp/verify', async (req, res) => {
  const normalizedMobile = normalizeIndianMobile(req.body?.mobile)
  const otp = String(req.body?.otp || '').trim()

  if (!normalizedMobile) {
    return res.status(400).json({
      success: false,
      message: 'Please provide valid mobile and OTP.',
    })
  }

  return handleVerifyOtpRequest(normalizedMobile, otp, res, {
    onVerified: () =>
      res.json({
        success: true,
        message: 'OTP verified successfully.',
        data: { mobile: normalizedMobile },
      }),
  })
})

app.post('/api/user/signup', (req, res) => {
  const fullName = String(req.body?.fullName || '').trim()
  const mobile = normalizeIndianMobile(req.body?.mobile)
  const email = String(req.body?.email || '').trim().toLowerCase()
  const password = String(req.body?.password || '')

  if (fullName.length < 2) {
    return res.status(400).json({ success: false, message: 'Please enter your full name.' })
  }
  if (!mobile) {
    return res.status(400).json({
      success: false,
      message: 'Please provide a valid 10 digit mobile number.',
    })
  }
  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return res.status(400).json({ success: false, message: 'Please enter a valid email address.' })
  }
  if (password.length < 6) {
    return res.status(400).json({
      success: false,
      message: 'Password must be at least 6 characters.',
    })
  }

  if (getUserByMobile(mobile) || getLatestSubmissionByMobile(mobile)) {
    return res.status(409).json({
      success: false,
      message: 'An account already exists for this mobile number. Please sign in.',
    })
  }

  const emailTaken = readUsers().some(
    (user) => String(user.email || '').trim().toLowerCase() === email,
  )
  if (emailTaken) {
    return res.status(409).json({
      success: false,
      message: 'An account already exists for this email address. Please sign in.',
    })
  }

  const user = upsertUserProfile({
    mobile,
    fullName,
    email,
    username: mobile,
    passwordHash: hashPassword(password),
    kycStatus: 'registered',
    loanStatus: 'none',
    documents: {},
    disbursedAmount: 0,
  })

  return res.status(201).json({
    success: true,
    message: 'Account created successfully.',
    data: {
      token: issueUserToken(user),
      user: buildUserProfileResponse(user),
    },
  })
})

app.post('/api/user/login/send-otp', async (req, res) => {
  const mobile = normalizeIndianMobile(req.body?.mobile)
  if (!mobile) {
    return res
      .status(400)
      .json({ success: false, message: 'Please provide a valid 10 digit mobile number.' })
  }

  const user = resolveUserAccount(mobile)
  if (!user) {
    return res.status(404).json({
      success: false,
      message: 'No account found for this mobile number. Please sign up first.',
    })
  }

  return handleSendOtpRequest(mobile, res)
})

app.post('/api/user/login/verify', async (req, res) => {
  const mobile = normalizeIndianMobile(req.body?.mobile)
  const otp = String(req.body?.otp || '').trim()

  if (!mobile) {
    return res.status(400).json({
      success: false,
      message: 'Please provide valid mobile and OTP.',
    })
  }

  const user = resolveUserAccount(mobile)
  if (!user) {
    return res.status(404).json({
      success: false,
      message: 'No account found for this mobile number.',
    })
  }

  return handleVerifyOtpRequest(mobile, otp, res, {
    onVerified: () =>
      res.json({
        success: true,
        message: 'Signed in successfully.',
        data: {
          token: issueUserToken(user),
          user: toSafeUser(user),
        },
      }),
  })
})

function findUserForPasswordLogin(mobileOrUsername) {
  const mobile = normalizeIndianMobile(mobileOrUsername)
  if (mobile) {
    const byMobile = getUserByMobile(mobile)
    if (byMobile) return byMobile
  }

  const loginId = String(mobileOrUsername || '').trim().toLowerCase()
  if (!loginId) return null

  return (
    readUsers().find((user) => String(user.username || '').trim().toLowerCase() === loginId) || null
  )
}

function loginWithPasswordHandler(req, res) {
  const mobileOrUsername = String(req.body?.mobile || req.body?.username || '').trim()
  const password = String(req.body?.password || '')

  if (!mobileOrUsername || !password) {
    return res.status(400).json({
      success: false,
      message: 'Please provide mobile number and password.',
    })
  }

  if (password.length < 6) {
    return res.status(400).json({
      success: false,
      message: 'Password must be at least 6 characters.',
    })
  }

  const user = findUserForPasswordLogin(mobileOrUsername)
  if (!user) {
    return res.status(404).json({
      success: false,
      message: 'No account found for this mobile number. Please sign up first.',
    })
  }

  if (!user.passwordHash) {
    return res.status(400).json({
      success: false,
      message:
        'Password login is not set up for this account. Complete KYC to set a password, or sign in with OTP.',
    })
  }

  if (!verifyPassword(password, user.passwordHash)) {
    return res.status(401).json({
      success: false,
      message: 'Invalid mobile number or password.',
    })
  }

  return res.json({
    success: true,
    message: 'Signed in successfully.',
    data: {
      token: issueUserToken(user),
      user: toSafeUser(user),
    },
  })
}

app.post('/api/user/login/password', loginWithPasswordHandler)
// Alias for clients that post to /api/user/login
app.post('/api/user/login', loginWithPasswordHandler)

app.post(
  '/api/kyc/submit',
  upload.fields([
    { name: 'aadhaarDoc', maxCount: 1 },
    { name: 'panDoc', maxCount: 1 },
    { name: 'salarySlips', maxCount: 1 },
    { name: 'bankStatements', maxCount: 1 },
    { name: 'photograph', maxCount: 1 },
    { name: 'signature', maxCount: 1 },
    { name: 'selfie', maxCount: 1 },
  ]),
  (req, res) => {
    try {
    const mobile = normalizeIndianMobile(req.body?.mobile)
    if (!mobile) {
      return res.status(400).json({ success: false, message: 'Valid mobile number is required.' })
    }

    const pan = sanitizePan(req.body?.pan)
    const aadhaar = sanitizeAadhaar(req.body?.aadhaar)
    const panError = getPanError(pan)
    const aadhaarError = getAadhaarError(aadhaar)
    const email = String(req.body?.email || '').trim().toLowerCase()
    const username = String(req.body?.username || '').trim()
    const password = String(req.body?.password || '')

    if (panError) {
      return res.status(400).json({ success: false, message: panError })
    }
    if (aadhaarError) {
      return res.status(400).json({ success: false, message: aadhaarError })
    }
    if (!email || !email.includes('@')) {
      return res.status(400).json({ success: false, message: 'Valid email address is required.' })
    }
    if (username.length < 4) {
      return res.status(400).json({ success: false, message: 'Username must be at least 4 characters.' })
    }
    if (password.length < 6) {
      return res.status(400).json({ success: false, message: 'Password must be at least 6 characters.' })
    }

    const documents = {}
    for (const [field, files] of Object.entries(req.files || {})) {
      if (files?.[0]) {
        documents[field] = {
          originalName: files[0].originalname,
          fileName: files[0].filename,
          url: `/uploads/${files[0].filename}`,
        }
      }
    }

    if (!documents.photograph || !documents.signature) {
      return res.status(400).json({
        success: false,
        message: 'Profile photograph and signature are required.',
      })
    }

    let communicationPreferences = {
      sms: true,
      email: true,
      phone: false,
      whatsapp: false,
    }
    try {
      const parsed = JSON.parse(req.body.communicationPreferences || '{}')
      communicationPreferences = { ...communicationPreferences, ...parsed }
    } catch {
      // keep defaults
    }

    const pinCode = String(req.body.pinCode || '').replace(/\D/g, '').slice(0, 6)
    const loanPurpose = String(req.body.loanPurpose || '').trim()
    const loanAmount = Math.min(Math.max(Number(req.body.loanAmount) || 0, 0), 200000)
    const processingFee = Math.max(Number(req.body.processingFee) || 0, 0)
    const emi = Math.max(Number(req.body.emi) || 0, 0)
    const totalPayable = Math.max(Number(req.body.totalPayable) || 0, 0)
    const netCreditedAmount = Math.max(Number(req.body.netCreditedAmount) || 0, 0)
    const offerValidUntil = req.body.offerValidUntil || ''
    const residentialAddress = String(req.body.residentialAddress || req.body.address || '').trim()
    const permanentAddress = String(req.body.permanentAddress || residentialAddress).trim()
    const passwordHash = hashPassword(password)

    const now = new Date().toISOString()
    const submission = {
      id: `KYC-${Date.now()}`,
      mobile,
      fullName: String(req.body.fullName || '').trim(),
      parentName: String(req.body.parentName || '').trim(),
      dateOfBirth: String(req.body.dateOfBirth || '').trim(),
      gender: String(req.body.gender || '').trim(),
      email,
      residentialAddress,
      permanentAddress,
      address: residentialAddress,
      occupation: String(req.body.occupation || '').trim(),
      employerDetails: String(req.body.employerDetails || '').trim(),
      employment: String(req.body.occupation || req.body.employment || '').trim(),
      incomeDetails: String(req.body.incomeDetails || '').trim(),
      income: String(req.body.income || req.body.incomeDetails || '').trim(),
      educationalInfo: String(req.body.educationalInfo || '').trim(),
      nomineeName: String(req.body.nomineeName || '').trim(),
      nomineeRelation: String(req.body.nomineeRelation || '').trim(),
      nomineeMobile: String(req.body.nomineeMobile || '').replace(/\D/g, '').slice(0, 10),
      emergencyContactName: String(req.body.emergencyContactName || '').trim(),
      emergencyContactRelation: String(req.body.emergencyContactRelation || '').trim(),
      emergencyContactMobile: String(req.body.emergencyContactMobile || '')
        .replace(/\D/g, '')
        .slice(0, 10),
      reference1Name: String(req.body.reference1Name || '').trim(),
      reference1Mobile: String(req.body.reference1Mobile || '').replace(/\D/g, '').slice(0, 10),
      reference2Name: String(req.body.reference2Name || '').trim(),
      reference2Mobile: String(req.body.reference2Mobile || '').replace(/\D/g, '').slice(0, 10),
      username,
      customerFeedback: String(req.body.customerFeedback || '').trim(),
      communicationPreferences,
      aadhaar,
      pan,
      accountNumber: String(req.body.accountNumber || '').trim(),
      ifsc: String(req.body.ifsc || '').trim(),
      pinCode,
      loanPurpose,
      loanAmount,
      processingFee,
      emi,
      totalPayable,
      netCreditedAmount,
      offerValidUntil,
      eSignConsent: req.body.eSignConsent === 'true',
      documents,
      cibilReport: emptyCibilReport(),
      status: 'submitted',
      submittedAt: now,
      updatedAt: now,
    }
    submission.verifications = buildVerificationState(submission)

    const submissions = readSubmissions()
    submissions.unshift(submission)
    writeSubmissions(submissions)

    const user = upsertUserProfile({
      mobile,
      fullName: submission.fullName,
      parentName: submission.parentName,
      dateOfBirth: submission.dateOfBirth,
      gender: submission.gender,
      email: submission.email,
      residentialAddress: submission.residentialAddress,
      permanentAddress: submission.permanentAddress,
      address: submission.address,
      occupation: submission.occupation,
      employerDetails: submission.employerDetails,
      employment: submission.employment,
      incomeDetails: submission.incomeDetails,
      income: submission.income,
      educationalInfo: submission.educationalInfo,
      nomineeName: submission.nomineeName,
      nomineeRelation: submission.nomineeRelation,
      nomineeMobile: submission.nomineeMobile,
      emergencyContactName: submission.emergencyContactName,
      emergencyContactRelation: submission.emergencyContactRelation,
      emergencyContactMobile: submission.emergencyContactMobile,
      reference1Name: submission.reference1Name,
      reference1Mobile: submission.reference1Mobile,
      reference2Name: submission.reference2Name,
      reference2Mobile: submission.reference2Mobile,
      username: submission.username,
      passwordHash,
      customerFeedback: submission.customerFeedback,
      communicationPreferences: submission.communicationPreferences,
      aadhaar: submission.aadhaar,
      pan: submission.pan,
      accountNumber: submission.accountNumber,
      ifsc: submission.ifsc,
      pinCode: submission.pinCode,
      loanPurpose: submission.loanPurpose,
      loanAmount: submission.loanAmount,
      processingFee: submission.processingFee,
      emi: submission.emi,
      totalPayable: submission.totalPayable,
      netCreditedAmount: submission.netCreditedAmount,
      offerValidUntil: submission.offerValidUntil,
      eSignConsent: submission.eSignConsent,
      documents: submission.documents,
      kycStatus: 'submitted',
      loanStatus: 'pending_disbursal',
      disbursedAmount: 0,
      kycId: submission.id,
    })

    const safeUser = { ...user }
    delete safeUser.passwordHash

    const userToken = jwt.sign(
      { role: 'user', mobile: user.mobile, userId: user.id },
      JWT_SECRET,
      { expiresIn: '7d' },
    )

    // Fire-and-forget CIBIL pull after authenticated loan application is created.
    requestCibilForSubmission(submission, { triggeredBy: 'kyc_submit' }).catch((error) => {
      console.error('Auto CIBIL request failed:', error?.message || error)
    })

    return res.json({
      success: true,
      message: 'KYC submitted successfully. Account created.',
      data: {
        submission,
        user: safeUser,
        token: userToken,
      },
    })
    } catch (error) {
      console.error('KYC submit error:', error)
      return res.status(500).json({
        success: false,
        message: 'Could not save your application. Please try again.',
      })
    }
  },
)

function syncUserFromSubmission(submission) {
  if (!submission?.mobile) return

  const users = readUsers()
  const userIndex = users.findIndex((item) => item.mobile === submission.mobile)
  if (userIndex < 0) return

  const normalized = normalizeSubmission(submission)
  users[userIndex] = {
    ...users[userIndex],
    fullName: normalized.fullName || users[userIndex].fullName,
    aadhaar: normalized.aadhaar || users[userIndex].aadhaar,
    pan: normalized.pan || users[userIndex].pan,
    address: normalized.address || users[userIndex].address,
    employment: normalized.employment || users[userIndex].employment,
    income: normalized.income || users[userIndex].income,
    accountNumber: normalized.accountNumber || users[userIndex].accountNumber,
    ifsc: normalized.ifsc || users[userIndex].ifsc,
    pinCode: normalized.pinCode || users[userIndex].pinCode,
    loanPurpose: normalized.loanPurpose || users[userIndex].loanPurpose,
    loanAmount: normalized.loanAmount ?? users[userIndex].loanAmount,
    processingFee: normalized.processingFee ?? users[userIndex].processingFee,
    emi: normalized.emi ?? users[userIndex].emi,
    totalPayable: normalized.totalPayable ?? users[userIndex].totalPayable,
    netCreditedAmount: normalized.netCreditedAmount ?? users[userIndex].netCreditedAmount,
    eSignConsent: normalized.eSignConsent ?? users[userIndex].eSignConsent,
    documents: normalized.documents || users[userIndex].documents,
    kycStatus: normalized.status === 'verified' ? 'verified' : normalized.status,
    kycId: normalized.id,
    verifications: normalized.verifications,
    applicationStatus: normalized.status,
    updatedAt: new Date().toISOString(),
  }
  writeUsers(users)
}

function buildApplicationSummary(submission) {
  const normalized = normalizeSubmission(submission)
  const fields = Object.values(normalized.verifications?.fields || {})
  const docs = Object.values(normalized.verifications?.documents || {})
  const all = [...fields, ...docs]
  const accepted = all.filter((item) => item.status === 'accepted').length
  const rejected = all.filter((item) => item.status === 'rejected').length
  const pending = all.length - accepted - rejected

  return {
    ...normalized,
    cibilReport: toPublicCibilReport(normalized.cibilReport),
    counts: {
      total: all.length,
      accepted,
      rejected,
      pending,
    },
  }
}

function isApplicationFullyApproved(application) {
  if (!application) return false
  if (application.status === 'verified') return true
  const counts = application.counts || {}
  return counts.pending === 0 && counts.rejected === 0 && counts.accepted > 0
}

function buildUserNotifications(application) {
  const notifications = []
  if (!application) return notifications

  if (isApplicationFullyApproved(application)) {
    const amount = Number(application.loanAmount || 0)
    const amountLabel = amount
      ? `₹${amount.toLocaleString('en-IN')}`
      : 'your requested amount'
    notifications.push({
      id: `loan-approved-${application.id}`,
      type: 'loan_approved',
      title: 'Your loan is approved',
      message: `Congratulations! All documents and details for your ${amountLabel} loan have been approved by our team.`,
      loanAmount: application.loanAmount || 0,
      applicationId: application.id,
      createdAt:
        application.reviewedAt || application.updatedAt || application.submittedAt,
    })
  } else if (application.counts?.rejected > 0) {
    notifications.push({
      id: `loan-action-required-${application.id}`,
      type: 'action_required',
      title: 'Action required on your application',
      message: `${application.counts.rejected} item(s) need correction. Please review your application in profile.`,
      applicationId: application.id,
      createdAt: application.updatedAt || application.submittedAt,
    })
  } else if (application.status === 'in_review' || application.status === 'submitted') {
    notifications.push({
      id: `loan-in-review-${application.id}`,
      type: 'in_review',
      title: 'Application under review',
      message: 'Your documents and details are being reviewed by our team.',
      applicationId: application.id,
      createdAt: application.updatedAt || application.submittedAt,
    })
  }

  return notifications
}

function buildUserProfileResponse(user) {
  const submissions = readSubmissions()
    .filter((item) => item.mobile === user.mobile)
    .map((item) => {
      const summary = buildApplicationSummary(item)
      return {
        ...summary,
        canCheckCibil: isLoanApplicationActive(summary, user),
      }
    })

  const application =
    submissions.find((item) => item.id === user.kycId) || submissions[0] || null

  const loanApproved = isApplicationFullyApproved(application)
  const notifications = buildUserNotifications(application)

  const safeUser = { ...user }
  delete safeUser.passwordHash

  return {
    ...safeUser,
    applications: submissions,
    application,
    cibilReport: toPublicCibilReport(application?.cibilReport || user.cibilReport),
    verifications: application?.verifications || user.verifications || { fields: {}, documents: {} },
    kycStatus: application?.status || safeUser.kycStatus || 'submitted',
    loanStatus:
      application && application.status !== 'verified'
        ? 'pending_disbursal'
        : safeUser.loanStatus || 'pending_disbursal',
    applicationStatus: application?.status || user.applicationStatus || user.kycStatus || 'submitted',
    documents: application?.documents || user.documents || {},
    loanApproved,
    notifications,
    canCheckCibil: isLoanApplicationActive(application, user),
  }
}

app.get('/api/user/profile', requireUserAuth, (req, res) => {
  const users = readUsers()
  const user = users.find((item) => item.mobile === req.user.mobile)

  if (!user) {
    return res.status(404).json({ success: false, message: 'User profile not found.' })
  }

  return res.json({ success: true, data: buildUserProfileResponse(user) })
})

app.get('/api/user/cibil', requireUserAuth, (req, res) => {
  const user = getUserByMobile(req.user.mobile)
  if (!user) {
    return res.status(404).json({ success: false, message: 'User profile not found.' })
  }

  const application = findActiveApplicationForMobile(req.user.mobile)
  if (!application) {
    return res.status(403).json({
      success: false,
      message: 'CIBIL report is only available while your loan application is in progress.',
    })
  }

  return res.json({
    success: true,
    data: {
      applicationId: application.id,
      canCheckCibil: true,
      cibilReport: toPublicCibilReport(application.cibilReport),
    },
  })
})

app.post('/api/user/cibil/request', requireUserAuth, async (req, res) => {
  const user = getUserByMobile(req.user.mobile)
  if (!user) {
    return res.status(404).json({ success: false, message: 'User profile not found.' })
  }

  const application = findActiveApplicationForMobile(req.user.mobile)
  if (!application) {
    return res.status(403).json({
      success: false,
      message: 'CIBIL report can only be checked after login while your loan application is active.',
    })
  }

  const consent = String(req.body?.consent || req.body?.Concent || 'Y').toUpperCase()
  if (consent !== 'Y' && consent !== 'YES' && consent !== 'TRUE') {
    return res.status(400).json({
      success: false,
      message: 'End-user consent is required to fetch the CIBIL report.',
    })
  }

  const result = await requestCibilForSubmission(application, { triggeredBy: 'user' })
  if (!result.ok) {
    return res.status(result.statusCode || 502).json({
      success: false,
      message: result.message,
      error: result.error,
    })
  }

  return res.json({
    success: true,
    message: result.message,
    data: {
      applicationId: application.id,
      cibilReport: result.data,
    },
  })
})

app.post('/api/admin/cibil/:id/request', requireAdminAuth, async (req, res) => {
  const submissionId = String(req.params.id || '')
  const submission = getSubmissionById(submissionId)
  if (!submission) {
    return res.status(404).json({ success: false, message: 'Submission not found.' })
  }

  const user = getUserByMobile(submission.mobile)
  if (!isLoanApplicationActive(submission, user)) {
    return res.status(403).json({
      success: false,
      message: 'CIBIL report is only available for users with an active loan application.',
    })
  }

  const result = await requestCibilForSubmission(submission, { triggeredBy: 'admin' })
  if (!result.ok) {
    return res.status(result.statusCode || 502).json({
      success: false,
      message: result.message,
      error: result.error,
    })
  }

  const refreshed = getSubmissionById(submissionId)
  return res.json({
    success: true,
    message: result.message,
    data: {
      ...normalizeSubmission(refreshed),
      cibilReport: toPublicCibilReport(refreshed?.cibilReport),
    },
  })
})

app.get('/api/admin/cibil/:id', requireAdminAuth, (req, res) => {
  const submission = getSubmissionById(String(req.params.id || ''))
  if (!submission) {
    return res.status(404).json({ success: false, message: 'Submission not found.' })
  }

  const user = getUserByMobile(submission.mobile)
  return res.json({
    success: true,
    data: {
      applicationId: submission.id,
      canCheckCibil: isLoanApplicationActive(submission, user),
      cibilReport: toPublicCibilReport(submission.cibilReport),
    },
  })
})

app.post('/api/cibil/callback', (req, res) => {
  try {
    const payload = req.body || {}
    const submission = matchSubmissionFromCibilCallback(payload)
    if (!submission) {
      console.warn('CIBIL callback received but no matching submission found.')
      return res.status(202).json({ success: true, message: 'Callback accepted.' })
    }

    const score = extractCibilScore(payload)
    updateSubmissionCibil(submission.id, {
      status: 'ready',
      report: payload?.report || payload?.data || payload,
      providerResponse: payload,
      score,
      summary: summarizeCibilPayload(payload),
      error: null,
    })

    return res.json({ success: true, message: 'CIBIL callback processed.' })
  } catch (error) {
    console.error('CIBIL callback error:', error)
    return res.status(500).json({ success: false, message: 'Failed to process CIBIL callback.' })
  }
})

app.post('/api/user/loan/complete', requireUserAuth, (req, res) => {
  const users = readUsers()
  const index = users.findIndex((item) => item.mobile === req.user.mobile)

  if (index < 0) {
    return res.status(404).json({ success: false, message: 'User profile not found.' })
  }

  const submissions = readSubmissions()
  const submissionIndex = submissions.findIndex((item) => item.mobile === req.user.mobile)
  const submission =
    submissionIndex >= 0 ? normalizeSubmission(submissions[submissionIndex]) : null

  if (!submission || submission.status !== 'verified') {
    return res.status(409).json({
      success: false,
      message: 'Your application must be approved by an admin before disbursement.',
    })
  }

  users[index] = {
    ...users[index],
    loanStatus: 'disbursed',
    kycStatus: 'verified',
    disbursedAmount: users[index].netCreditedAmount || users[index].loanAmount || 0,
    disbursedAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  }
  writeUsers(users)

  if (submissionIndex >= 0) {
    submissions[submissionIndex] = {
      ...submissions[submissionIndex],
      status: 'verified',
    }
    writeSubmissions(submissions)
  }

  return res.json({
    success: true,
    message: 'Loan marked as disbursed.',
    data: users[index],
  })
})

app.get('/api/admin/stats', requireAdminAuth, (_req, res) => {
  return res.json({ success: true, data: buildAdminStats() })
})

function syncUserKycStatus(mobile, status) {
  const users = readUsers()
  const userIndex = users.findIndex((item) => item.mobile === mobile)
  if (userIndex < 0) return

  const submission =
    readSubmissions().find((item) => item.mobile === mobile) || null

  users[userIndex] = {
    ...users[userIndex],
    kycStatus: status === 'verified' ? 'verified' : status,
    applicationStatus: status,
    verifications: submission
      ? normalizeSubmission(submission).verifications
      : users[userIndex].verifications,
    updatedAt: new Date().toISOString(),
  }
  writeUsers(users)
}

app.patch('/api/admin/kyc/:id/status', requireAdminAuth, (req, res) => {
  const submissionId = String(req.params.id || '')
  const status = String(req.body?.status || '').trim()

  if (!['verified', 'submitted', 'rejected', 'in_review'].includes(status)) {
    return res.status(400).json({ success: false, message: 'Invalid status value.' })
  }

  const submissions = readSubmissions()
  const submissionIndex = submissions.findIndex((item) => item.id === submissionId)

  if (submissionIndex < 0) {
    return res.status(404).json({ success: false, message: 'Submission not found.' })
  }

  const now = new Date().toISOString()
  const current = normalizeSubmission(submissions[submissionIndex])
  const verifications = current.verifications

  if (status === 'verified') {
    Object.keys(verifications.fields).forEach((key) => {
      verifications.fields[key] = { status: 'accepted', updatedAt: now }
    })
    Object.keys(verifications.documents).forEach((key) => {
      verifications.documents[key] = { status: 'accepted', updatedAt: now }
    })
  } else if (status === 'rejected') {
    Object.keys(verifications.fields).forEach((key) => {
      verifications.fields[key] = { status: 'rejected', updatedAt: now }
    })
    Object.keys(verifications.documents).forEach((key) => {
      verifications.documents[key] = { status: 'rejected', updatedAt: now }
    })
  } else if (status === 'submitted') {
    Object.keys(verifications.fields).forEach((key) => {
      verifications.fields[key] = { status: 'pending', updatedAt: now }
    })
    Object.keys(verifications.documents).forEach((key) => {
      verifications.documents[key] = { status: 'pending', updatedAt: now }
    })
  }

  submissions[submissionIndex] = {
    ...current,
    verifications,
    status,
    reviewedAt: now,
    updatedAt: now,
  }
  writeSubmissions(submissions)
  syncUserFromSubmission(submissions[submissionIndex])

  const updated = normalizeSubmission(submissions[submissionIndex])
  return res.json({
    success: true,
    message: `Submission marked as ${status}.`,
    data: {
      ...updated,
      cibilReport: toPublicCibilReport(updated.cibilReport),
      canCheckCibil: isLoanApplicationActive(updated, getUserByMobile(updated.mobile)),
    },
  })
})

app.patch('/api/admin/kyc/:id/item-status', requireAdminAuth, (req, res) => {
  const submissionId = String(req.params.id || '')
  const type = String(req.body?.type || '').trim()
  const key = String(req.body?.key || '').trim()
  const status = String(req.body?.status || '').trim()

  if (!['field', 'document'].includes(type)) {
    return res.status(400).json({ success: false, message: 'type must be field or document.' })
  }
  if (!key) {
    return res.status(400).json({ success: false, message: 'key is required.' })
  }
  if (!['accepted', 'rejected', 'pending'].includes(status)) {
    return res
      .status(400)
      .json({ success: false, message: 'status must be accepted, rejected, or pending.' })
  }

  const submissions = readSubmissions()
  const submissionIndex = submissions.findIndex((item) => item.id === submissionId)

  if (submissionIndex < 0) {
    return res.status(404).json({ success: false, message: 'Submission not found.' })
  }

  const submission = normalizeSubmission(submissions[submissionIndex])
  const bucket = type === 'field' ? submission.verifications.fields : submission.verifications.documents

  if (!bucket[key]) {
    return res.status(404).json({
      success: false,
      message: `${type} "${key}" not found on this submission.`,
    })
  }

  const now = new Date().toISOString()
  bucket[key] = { status, updatedAt: now }

  const overallStatus = computeOverallStatus(submission.verifications)
  submissions[submissionIndex] = {
    ...submission,
    verifications: submission.verifications,
    status: overallStatus,
    reviewedAt: now,
    updatedAt: now,
  }
  writeSubmissions(submissions)
  syncUserFromSubmission(submissions[submissionIndex])

  const updated = normalizeSubmission(submissions[submissionIndex])
  return res.json({
    success: true,
    message: `${type} "${key}" marked as ${status}.`,
    data: {
      ...updated,
      cibilReport: toPublicCibilReport(updated.cibilReport),
      canCheckCibil: isLoanApplicationActive(updated, getUserByMobile(updated.mobile)),
    },
  })
})

app.get('/api/kyc/submissions', requireAdminAuth, (_req, res) => {
  const submissions = readSubmissions()
  const normalizedForStorage = submissions.map(normalizeSubmission)
  const needsWrite = normalizedForStorage.some((item, index) => {
    const raw = submissions[index]
    return !raw.verifications || !raw.updatedAt || raw.status !== item.status
  })
  if (needsWrite) {
    writeSubmissions(normalizedForStorage)
  }

  const payload = (needsWrite ? normalizedForStorage : submissions).map((item) => {
    const base = normalizeSubmission(item)
    return {
      ...base,
      cibilReport: toPublicCibilReport(base.cibilReport),
      canCheckCibil: isLoanApplicationActive(base, getUserByMobile(base.mobile)),
    }
  })
  return res.json({ success: true, data: payload })
})

app.get('/uploads/:fileName', requireAdminAuth, (req, res) => {
  const fileName = path.basename(req.params.fileName)
  const filePath = path.join(uploadsDir, fileName)

  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ success: false, message: 'File not found.' })
  }

  return res.sendFile(filePath)
})

app.use((error, _req, res, next) => {
  if (error?.code === 'LIMIT_FILE_SIZE') {
    return res.status(400).json({ success: false, message: 'Uploaded file is too large.' })
  }
  if (error instanceof multer.MulterError) {
    return res.status(400).json({ success: false, message: error.message || 'File upload failed.' })
  }
  return next(error)
})

app.listen(PORT, () => {
  console.log(`Backend running on port ${PORT}`)
  console.log(
    `OTP mode: LIVE MSG91 only — ${MSG91_OTP_LENGTH}-digit codes verified via MSG91 (no debug bypass)`,
  )
  if (!MSG91_AUTH_KEY || !MSG91_TEMPLATE_ID) {
    console.warn('WARNING: MSG91_AUTH_KEY or MSG91_TEMPLATE_ID missing — OTP send/verify will fail.')
  }
  if (!TRUDETAILS_KEY) {
    console.warn('WARNING: API_KEY / TRUDETAILS_API_KEY missing — CIBIL fetch will fail.')
  } else if (!PUBLIC_BASE_URL && !CIBIL_CALLBACK_URL) {
    console.warn(
      'WARNING: PUBLIC_BASE_URL or CIBIL_CALLBACK_URL missing — TruDetails callback may not reach this server.',
    )
  }
})
