import { useEffect, useState } from 'react'
import { WebsiteLayout } from './WebsiteLayout'
import HomePage from './pages/HomePage'
import AboutPage from './pages/AboutPage'
import ServicesPage from './pages/ServicesPage'
import CsrPage from './pages/CsrPage'
import ContactPage from './pages/ContactPage'
import PrivacyPage from './pages/PrivacyPage'
import CibilPage from './pages/CibilPage'
import SignUpPage from './pages/SignUpPage'
import UserProfilePage from '../components/UserProfilePage'

function CompanyWebsite({
  userProfile,
  userToken,
  profileMode,
  onApplyNow,
  onViewProfile,
  onLeaveProfile,
  onSignIn,
  onSignedUp,
  onLogout,
  onProfileRefresh,
  requestedPage,
  onRequestedPageConsumed,
}) {
  const [currentPage, setCurrentPage] = useState(profileMode ? 'profile' : 'home')

  useEffect(() => {
    if (profileMode) {
      setCurrentPage('profile')
    }
  }, [profileMode])

  useEffect(() => {
    if (!requestedPage) return
    setCurrentPage(requestedPage)
    if (requestedPage !== 'profile') {
      onLeaveProfile?.()
    }
    onRequestedPageConsumed?.()
  }, [requestedPage, onLeaveProfile, onRequestedPageConsumed])

  useEffect(() => {
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }, [currentPage])

  function handleNavigate(pageId) {
    setCurrentPage(pageId)
    if (pageId !== 'profile') {
      onLeaveProfile?.()
    }
  }

  function handleViewProfile() {
    setCurrentPage('profile')
    onViewProfile?.()
  }

  function renderPage() {
    if (currentPage === 'profile' && userProfile) {
      return (
        <UserProfilePage
          profile={userProfile}
          userToken={userToken}
          onLogout={onLogout}
          onBackHome={() => handleNavigate('home')}
          onProfileRefresh={onProfileRefresh}
        />
      )
    }

    const commonProps = {
      onApplyNow,
      onNavigate: handleNavigate,
    }

    switch (currentPage) {
      case 'about':
        return <AboutPage {...commonProps} />
      case 'services':
        return <ServicesPage {...commonProps} />
      case 'csr':
        return <CsrPage {...commonProps} />
      case 'contact':
        return <ContactPage />
      case 'privacy':
        return <PrivacyPage />
      case 'cibil':
        return (
          <CibilPage
            userProfile={userProfile}
            userToken={userToken}
            onSignIn={onSignIn}
            onApplyNow={onApplyNow}
          />
        )
      case 'signup':
        return (
          <SignUpPage
            userProfile={userProfile}
            onSignIn={onSignIn}
            onViewProfile={handleViewProfile}
            onSignedUp={(payload) => {
              setCurrentPage('home')
              onSignedUp?.(payload)
            }}
          />
        )
      default:
        return <HomePage {...commonProps} />
    }
  }

  return (
    <WebsiteLayout
      currentPage={currentPage === 'profile' ? 'home' : currentPage}
      onNavigate={handleNavigate}
      onApplyNow={onApplyNow}
      onViewProfile={handleViewProfile}
      onSignIn={onSignIn}
      onLogout={onLogout}
      userProfile={userProfile}
    >
      {renderPage()}
    </WebsiteLayout>
  )
}

export default CompanyWebsite
