(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u1000))
(define-constant ERR_ALREADY_EXISTS (err u1001))
(define-constant ERR_NOT_FOUND (err u1002))
(define-constant ERR_INSUFFICIENT_FUNDS (err u1003))
(define-constant ERR_INVALID_AMOUNT (err u1004))
(define-constant ERR_NO_USAGE_METRICS (err u1005))


(define-constant ERR_MILESTONE_NOT_MET (err u1006))
(define-constant ERR_INVALID_MILESTONE (err u1007))

(define-map maintainers principal {
  project-name: (string-ascii 64),
  total-grants: uint,
  last-payout: uint,
  usage-score: uint,
  is-active: bool
})

(define-map funders principal {
  total-contributed: uint,
  active-streams: uint
})

(define-map project-usage (string-ascii 64) {
  downloads: uint,
  stars: uint,
  contributors: uint,
  last-updated: uint
})

(define-map streaming-grants uint {
  funder: principal,
  maintainer: principal,
  project-name: (string-ascii 64),
  rate-per-block: uint,
  total-funded: uint,
  remaining-funds: uint,
  start-block: uint,
  last-claim: uint,
  is-active: bool
})

(define-data-var grant-counter uint u0)
(define-data-var total-pool uint u0)

(define-read-only (get-maintainer (maintainer principal))
  (map-get? maintainers maintainer)
)

(define-read-only (get-funder (funder principal))
  (map-get? funders funder)
)

(define-read-only (get-project-usage (project-name (string-ascii 64)))
  (map-get? project-usage project-name)
)

(define-read-only (get-streaming-grant (grant-id uint))
  (map-get? streaming-grants grant-id)
)

(define-read-only (get-current-block)
  stacks-block-height
)

(define-read-only (calculate-payout-amount (grant-id uint))
  (match (map-get? streaming-grants grant-id)
    grant (let ((blocks-since-last (- stacks-block-height (get last-claim grant))))
            (* (get rate-per-block grant) blocks-since-last)
          )
    u0
  )
)

(define-public (register-maintainer (project-name (string-ascii 64)))
  (let ((caller tx-sender))
    (asserts! (is-none (map-get? maintainers caller)) ERR_ALREADY_EXISTS)
    (ok (map-set maintainers caller {
      project-name: project-name,
      total-grants: u0,
      last-payout: stacks-block-height,
      usage-score: u1,
      is-active: true
    }))
  )
)

(define-public (update-project-metrics (project-name (string-ascii 64)) (downloads uint) (stars uint) (contributors uint))
  (begin
    (asserts! (is-some (map-get? maintainers tx-sender)) ERR_NOT_AUTHORIZED)
    (let ((current-maintainer (unwrap! (map-get? maintainers tx-sender) ERR_NOT_FOUND)))
      (asserts! (is-eq (get project-name current-maintainer) project-name) ERR_NOT_AUTHORIZED)
      (let ((usage-score (+ downloads (* stars u2) (* contributors u5))))
        (map-set project-usage project-name {
          downloads: downloads,
          stars: stars,
          contributors: contributors,
          last-updated: stacks-block-height
        })
        (ok (map-set maintainers tx-sender (merge current-maintainer {usage-score: usage-score})))
      )
    )
  )
)

(define-public (create-streaming-grant (maintainer principal) (project-name (string-ascii 64)) (rate-per-block uint) (total-amount uint))
  (let ((grant-id (+ (var-get grant-counter) u1)))
    (asserts! (> total-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> rate-per-block u0) ERR_INVALID_AMOUNT)
    (asserts! (is-some (map-get? maintainers maintainer)) ERR_NOT_FOUND)
    (try! (stx-transfer? total-amount tx-sender (as-contract tx-sender)))
    
    (map-set streaming-grants grant-id {
      funder: tx-sender,
      maintainer: maintainer,
      project-name: project-name,
      rate-per-block: rate-per-block,
      total-funded: total-amount,
      remaining-funds: total-amount,
      start-block: stacks-block-height,
      last-claim: stacks-block-height,
      is-active: true
    })
    
    (match (map-get? funders tx-sender)
      funder-data (map-set funders tx-sender (merge funder-data {
        total-contributed: (+ (get total-contributed funder-data) total-amount),
        active-streams: (+ (get active-streams funder-data) u1)
      }))
      (map-set funders tx-sender {
        total-contributed: total-amount,
        active-streams: u1
      })
    )
    
    (var-set grant-counter grant-id)
    (var-set total-pool (+ (var-get total-pool) total-amount))
    (ok grant-id)
  )
)

(define-public (claim-grant (grant-id uint))
  (let ((grant (unwrap! (map-get? streaming-grants grant-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get maintainer grant)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active grant) ERR_NOT_FOUND)
    
    (let ((payout-amount (calculate-payout-amount grant-id))
          (maintainer-data (unwrap! (map-get? maintainers tx-sender) ERR_NOT_FOUND)))
     
      (asserts! (<= payout-amount (get remaining-funds grant)) ERR_INSUFFICIENT_FUNDS)
      (asserts! (> payout-amount u0) ERR_INVALID_AMOUNT)
      
      (let ((usage-multiplier (/ (get usage-score maintainer-data) u10))
            (adjusted-payout (/ (* payout-amount (+ u10 usage-multiplier)) u20)))
        
        (try! (as-contract (stx-transfer? adjusted-payout tx-sender tx-sender)))
        
        (let ((new-remaining (- (get remaining-funds grant) adjusted-payout)))
          (if (is-eq new-remaining u0)
            (map-set streaming-grants grant-id (merge grant {
              remaining-funds: new-remaining,
              last-claim: stacks-block-height,
              is-active: false
            }))
            (map-set streaming-grants grant-id (merge grant {
              remaining-funds: new-remaining,
              last-claim: stacks-block-height
            }))
          )
        )
        
        (map-set maintainers tx-sender (merge maintainer-data {
          total-grants: (+ (get total-grants maintainer-data) adjusted-payout),
          last-payout: stacks-block-height
        }))
        
        (ok adjusted-payout)
      )
    )
  )
)

(define-public (pause-grant (grant-id uint))
  (let ((grant (unwrap! (map-get? streaming-grants grant-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get funder grant)) ERR_NOT_AUTHORIZED)
    (ok (map-set streaming-grants grant-id (merge grant {is-active: false})))
  )
)

(define-public (resume-grant (grant-id uint))
  (let ((grant (unwrap! (map-get? streaming-grants grant-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get funder grant)) ERR_NOT_AUTHORIZED)
    (asserts! (> (get remaining-funds grant) u0) ERR_INSUFFICIENT_FUNDS)
    (ok (map-set streaming-grants grant-id (merge grant {is-active: true})))
  )
)

(define-read-only (get-total-pool)
  (var-get total-pool)
)

(define-read-only (get-grant-counter)
  (var-get grant-counter)
)


(define-map vesting-grants uint {
  funder: principal,
  maintainer: principal,
  project-name: (string-ascii 64),
  total-amount: uint,
  remaining-amount: uint,
  milestone-stars: (list 5 uint),
  milestone-percentages: (list 5 uint),
  milestones-unlocked: uint,
  is-active: bool
})

(define-data-var vesting-counter uint u0)

(define-read-only (get-vesting-grant (grant-id uint))
  (map-get? vesting-grants grant-id)
)

(define-read-only (check-milestone-eligibility (grant-id uint) (milestone-index uint))
  (match (map-get? vesting-grants grant-id)
    grant (match (map-get? project-usage (get project-name grant))
      metrics (let ((required-stars (default-to u0 (element-at (get milestone-stars grant) milestone-index)))
                    (current-stars (get stars metrics)))
                (ok (>= current-stars required-stars))
              )
      (ok false)
    )
    (ok false)
  )
)

(define-public (create-vesting-grant 
  (maintainer principal) 
  (project-name (string-ascii 64))
  (total-amount uint)
  (milestone-stars (list 5 uint))
  (milestone-percentages (list 5 uint)))
  
  (let ((vesting-id (+ (var-get vesting-counter) u1)))
    (asserts! (> total-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (is-eq (len milestone-stars) (len milestone-percentages)) ERR_INVALID_MILESTONE)
    (asserts! (is-some (map-get? maintainers maintainer)) ERR_NOT_FOUND)
    
    (try! (stx-transfer? total-amount tx-sender (as-contract tx-sender)))
    
    (map-set vesting-grants vesting-id {
      funder: tx-sender,
      maintainer: maintainer,
      project-name: project-name,
      total-amount: total-amount,
      remaining-amount: total-amount,
      milestone-stars: milestone-stars,
      milestone-percentages: milestone-percentages,
      milestones-unlocked: u0,
      is-active: true
    })
    
    (var-set vesting-counter vesting-id)
    (ok vesting-id)
  )
)

(define-public (unlock-milestone (grant-id uint))
  (let ((grant (unwrap! (map-get? vesting-grants grant-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get maintainer grant)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active grant) ERR_NOT_FOUND)
    
    (let ((next-milestone (get milestones-unlocked grant))
          (metrics (unwrap! (map-get? project-usage (get project-name grant)) ERR_NO_USAGE_METRICS)))
      
      (asserts! (< next-milestone (len (get milestone-stars grant))) ERR_INVALID_MILESTONE)
      
      (let ((required-stars (unwrap! (element-at (get milestone-stars grant) next-milestone) ERR_INVALID_MILESTONE))
            (payout-percent (unwrap! (element-at (get milestone-percentages grant) next-milestone) ERR_INVALID_MILESTONE)))
        
        (asserts! (>= (get stars metrics) required-stars) ERR_MILESTONE_NOT_MET)
        
        (let ((payout-amount (/ (* (get total-amount grant) payout-percent) u100)))
          (try! (as-contract (stx-transfer? payout-amount tx-sender (get maintainer grant))))
          
          (let ((new-remaining (- (get remaining-amount grant) payout-amount))
                (new-unlocked (+ next-milestone u1)))
            (map-set vesting-grants grant-id (merge grant {
              remaining-amount: new-remaining,
              milestones-unlocked: new-unlocked,
              is-active: (not (is-eq new-remaining u0))
            }))
            (ok payout-amount)
          )
        )
      )
    )
  )
)