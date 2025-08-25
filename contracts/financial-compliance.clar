;; Financial Regulation Compliance Contract
;; Ensures government financial practices meet audit and reporting standards

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-INVALID-INPUT (err u401))
(define-constant ERR-NOT-FOUND (err u402))
(define-constant ERR-ALREADY-EXISTS (err u403))

;; Data Variables
(define-data-var next-audit-id uint u1)
(define-data-var next-transaction-id uint u1)
(define-data-var next-budget-id uint u1)

;; Data Maps
(define-map financial-audits
  { audit-id: uint }
  {
    department: (string-ascii 100),
    audit-type: (string-ascii 50),
    auditor: principal,
    audit-period-start: uint,
    audit-period-end: uint,
    findings: (string-ascii 500),
    compliance-rating: (string-ascii 20),
    recommendations: (string-ascii 500),
    management-response: (string-ascii 500),
    status: (string-ascii 20),
    created-at: uint,
    updated-at: uint
  }
)

(define-map financial-transactions
  { transaction-id: uint }
  {
    department: (string-ascii 100),
    transaction-type: (string-ascii 50),
    amount: uint,
    description: (string-ascii 200),
    budget-category: (string-ascii 100),
    authorized-by: principal,
    approval-date: uint,
    transaction-date: uint,
    vendor: (string-ascii 100),
    compliance-status: (string-ascii 20),
    created-at: uint
  }
)

(define-map budget-allocations
  { budget-id: uint }
  {
    department: (string-ascii 100),
    fiscal-year: uint,
    budget-category: (string-ascii 100),
    allocated-amount: uint,
    spent-amount: uint,
    remaining-amount: uint,
    utilization-rate: uint,
    status: (string-ascii 20),
    created-at: uint,
    updated-at: uint
  }
)

(define-map user-roles
  { user: principal }
  { role: (string-ascii 20) }
)

(define-map department-managers
  { department: (string-ascii 100) }
  { manager: principal }
)

;; Authorization Functions
(define-private (is-authorized (user principal) (required-role (string-ascii 20)))
  (let ((user-role (default-to "public" (get role (map-get? user-roles { user: user })))))
    (or
      (is-eq user CONTRACT-OWNER)
      (is-eq user-role "admin")
      (is-eq user-role required-role)
      (is-eq user-role "financial-officer")
    )
  )
)

;; Public Functions

;; Set user role
(define-public (set-user-role (user principal) (role (string-ascii 20)))
  (begin
    (asserts! (is-authorized tx-sender "admin") ERR-NOT-AUTHORIZED)
    (asserts! (or (is-eq role "admin") (is-eq role "financial-officer")
                  (is-eq role "auditor") (is-eq role "manager") (is-eq role "public")) ERR-INVALID-INPUT)
    (ok (map-set user-roles { user: user } { role: role }))
  )
)

;; Assign department manager
(define-public (assign-department-manager (department (string-ascii 100)) (manager principal))
  (begin
    (asserts! (is-authorized tx-sender "admin") ERR-NOT-AUTHORIZED)
    (asserts! (> (len department) u0) ERR-INVALID-INPUT)
    (ok (map-set department-managers { department: department } { manager: manager }))
  )
)

;; Create budget allocation
(define-public (create-budget-allocation
  (department (string-ascii 100))
  (fiscal-year uint)
  (budget-category (string-ascii 100))
  (allocated-amount uint))
  (let ((budget-id (var-get next-budget-id)))
    (begin
      (asserts! (is-authorized tx-sender "financial-officer") ERR-NOT-AUTHORIZED)
      (asserts! (and (> (len department) u0) (> (len budget-category) u0)) ERR-INVALID-INPUT)
      (asserts! (> allocated-amount u0) ERR-INVALID-INPUT)

      (map-set budget-allocations
        { budget-id: budget-id }
        {
          department: department,
          fiscal-year: fiscal-year,
          budget-category: budget-category,
          allocated-amount: allocated-amount,
          spent-amount: u0,
          remaining-amount: allocated-amount,
          utilization-rate: u0,
          status: "active",
          created-at: block-height,
          updated-at: block-height
        }
      )

      (var-set next-budget-id (+ budget-id u1))
      (ok budget-id)
    )
  )
)

;; Record financial transaction
(define-public (record-transaction
  (department (string-ascii 100))
  (transaction-type (string-ascii 50))
  (amount uint)
  (description (string-ascii 200))
  (budget-category (string-ascii 100))
  (vendor (string-ascii 100))
  (budget-id uint))
  (let ((transaction-id (var-get next-transaction-id))
        (budget (unwrap! (map-get? budget-allocations { budget-id: budget-id }) ERR-NOT-FOUND)))
    (begin
      (asserts! (is-authorized tx-sender "manager") ERR-NOT-AUTHORIZED)
      (asserts! (and (> (len department) u0) (> (len transaction-type) u0)) ERR-INVALID-INPUT)
      (asserts! (> amount u0) ERR-INVALID-INPUT)
      (asserts! (<= amount (get remaining-amount budget)) ERR-INVALID-INPUT)

      ;; Record transaction
      (map-set financial-transactions
        { transaction-id: transaction-id }
        {
          department: department,
          transaction-type: transaction-type,
          amount: amount,
          description: description,
          budget-category: budget-category,
          authorized-by: tx-sender,
          approval-date: block-height,
          transaction-date: block-height,
          vendor: vendor,
          compliance-status: "approved",
          created-at: block-height
        }
      )

      ;; Update budget allocation
      (let ((new-spent (+ (get spent-amount budget) amount))
            (new-remaining (- (get remaining-amount budget) amount))
            (new-utilization (/ (* new-spent u100) (get allocated-amount budget))))
        (map-set budget-allocations
          { budget-id: budget-id }
          (merge budget {
            spent-amount: new-spent,
            remaining-amount: new-remaining,
            utilization-rate: new-utilization,
            updated-at: block-height
          })
        )
      )

      (var-set next-transaction-id (+ transaction-id u1))
      (ok transaction-id)
    )
  )
)

;; Conduct financial audit
(define-public (conduct-audit
  (department (string-ascii 100))
  (audit-type (string-ascii 50))
  (audit-period-start uint)
  (audit-period-end uint)
  (findings (string-ascii 500))
  (compliance-rating (string-ascii 20))
  (recommendations (string-ascii 500)))
  (let ((audit-id (var-get next-audit-id)))
    (begin
      (asserts! (is-authorized tx-sender "auditor") ERR-NOT-AUTHORIZED)
      (asserts! (and (> (len department) u0) (> (len audit-type) u0)) ERR-INVALID-INPUT)
      (asserts! (< audit-period-start audit-period-end) ERR-INVALID-INPUT)
      (asserts! (or (is-eq compliance-rating "excellent") (is-eq compliance-rating "good")
                    (is-eq compliance-rating "satisfactory") (is-eq compliance-rating "poor")) ERR-INVALID-INPUT)

      (map-set financial-audits
        { audit-id: audit-id }
        {
          department: department,
          audit-type: audit-type,
          auditor: tx-sender,
          audit-period-start: audit-period-start,
          audit-period-end: audit-period-end,
          findings: findings,
          compliance-rating: compliance-rating,
          recommendations: recommendations,
          management-response: "",
          status: "completed",
          created-at: block-height,
          updated-at: block-height
        }
      )

      (var-set next-audit-id (+ audit-id u1))
      (ok audit-id)
    )
  )
)

;; Submit management response to audit
(define-public (submit-management-response (audit-id uint) (response (string-ascii 500)))
  (let ((audit (unwrap! (map-get? financial-audits { audit-id: audit-id }) ERR-NOT-FOUND)))
    (begin
      (asserts! (is-authorized tx-sender "manager") ERR-NOT-AUTHORIZED)
      (asserts! (> (len response) u0) ERR-INVALID-INPUT)

      (map-set financial-audits
        { audit-id: audit-id }
        (merge audit {
          management-response: response,
          status: "responded",
          updated-at: block-height
        })
      )
      (ok true)
    )
  )
)

;; Read-only Functions

;; Get audit
(define-read-only (get-audit (audit-id uint))
  (map-get? financial-audits { audit-id: audit-id })
)

;; Get transaction
(define-read-only (get-transaction (transaction-id uint))
  (map-get? financial-transactions { transaction-id: transaction-id })
)

;; Get budget allocation
(define-read-only (get-budget-allocation (budget-id uint))
  (map-get? budget-allocations { budget-id: budget-id })
)

;; Get user role
(define-read-only (get-user-role (user principal))
  (default-to "public" (get role (map-get? user-roles { user: user })))
)

;; Get department manager
(define-read-only (get-department-manager (department (string-ascii 100)))
  (map-get? department-managers { department: department })
)

;; Get financial statistics
(define-read-only (get-financial-stats)
  {
    total-audits: (- (var-get next-audit-id) u1),
    total-transactions: (- (var-get next-transaction-id) u1),
    total-budgets: (- (var-get next-budget-id) u1)
  }
)
