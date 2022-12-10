<template>
  <div id="app">
    <b-navbar
      toggleable="lg"
      type="dark"
      variant="primary"
    >
      <b-navbar-brand href="#">
        BrowserPhone
      </b-navbar-brand>

      <b-navbar-toggle target="nav-collapse" />

      <b-collapse
        id="nav-collapse"
        is-nav
      >
        <b-navbar-nav class="ml-auto">
          <b-nav-text v-if="identity">
            Signed in as <strong>{{ identity }}</strong>
          </b-nav-text>
          <b-nav-item @click="setupPhone">
            Reload
          </b-nav-item>
        </b-navbar-nav>
      </b-collapse>
    </b-navbar>

    <b-container>
      <b-row class="justify-content-center mt-5">
        <b-col
          cols="12"
          md="6"
        >
          <b-card>
            <template v-if="phone.started">
              <b-form-input
                slot="header"
                v-model="number"
                autofocus
                class="my-2 number border-info"
                size="lg"
                type="tel"
                @keypress="evt => keypress(evt)"
              />

              <b-row class="justify-content-center">
                <b-col
                  v-for="key in keys"
                  :key="key"
                  cols="4"
                  class="text-center mb-3"
                >
                  <b-btn
                    size="lg"
                    @click="keyDown(key)"
                  >
                    {{ key }}
                  </b-btn>
                </b-col>

                <b-col
                  cols="4"
                  class="text-center mb-2"
                >
                  <b-btn
                    size="lg"
                    :variant="ongoingCall ? 'danger' : 'success'"
                    :disabled="!phoneReady"
                    @click="toggleCall"
                  >
                    <i :class="{ 'fas': true, 'fa-phone': !ongoingCall, 'fa-phone-slash': ongoingCall }" />
                  </b-btn>
                </b-col>
              </b-row>
            </template>

            <template v-else>
              <b-button @click="setupPhone">
                Initialize
              </b-button>
            </template>

            <div
              slot="footer"
              class="d-flex justify-content-between"
            >
              <span><template v-if="state.time">{{ stateDate }}</template> <template v-if="state.msg">{{ state.msg }}</template></span>
              <span>{{ callDuration }}</span>
            </div>
          </b-card>
        </b-col>
      </b-row>
    </b-container>
  </div>
</template>

<script>
import axios from 'axios'
import config from './config.js'
import { Device } from '@twilio/voice-sdk'

export default {
  computed: {
    callDuration() {
      if (!this.phone.callConnected) {
        return '--:--'
      }

      let secs = Math.round((new Date() - this.phone.callConnected) / 1000)
      const parts = []
      for (const div of [3600, 60, 1]) {
        const n = Math.floor(secs / div)
        secs -= n * div
        parts.append(n.toFixed(0).padStart(2, '0'))
      }

      return parts.join(':')
    },

    keys() {
      return ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#']
    },

    ongoingCall() {
      return this.phone.conn && this.phone.conn.status() === 'open'
    },

    pendingCall() {
      return this.phone.conn && this.phone.conn.status() === 'pending'
    },

    phoneReady() {
      return this.phone.device && this.phone.registered
    },

    stateDate() {
      if (!this.state.time) {
        return null
      }

      return [
        this.state.time.getHours().toFixed(0)
          .padStart(2, '0'),
        this.state.time.getMinutes().toFixed(0)
          .padStart(2, '0'),
      ].join(':')
    },
  },

  data() {
    return {
      backoff: {
        current: 100,
        initial: 100,
        max: 30000,
        multiplier: 1.25,
      },

      identity: null,
      now: new Date(),
      number: '',
      phone: {
        callConnected: null,
        conn: null,
        device: null,
        registered: false,
        started: false,
      },

      state: {
        msg: '',
        time: null,
      },

      wakeLock: {
        obj: null,
        request: null,
      },
    }
  },

  methods: {
    announceStatus(state, autoClear = false) {
      this.state.msg = state
      this.state.time = new Date()

      if (autoClear) {
        window.setTimeout(() => {
          this.state.msg = ''
          this.state.time = null
        }, 2000)
      }
    },

    handleCall(call) {
      this.phone.conn = call

      this.phone.conn.on('accept', conn => {
        this.phone.conn = conn
        this.phone.callConnected = new Date()
        this.announceStatus('Call connected')
        this.setWakeLock(true)
      })

      this.phone.conn.on('disconnect', () => {
        this.phone.conn = null
        this.phone.callConnected = null
        this.announceStatus('Call disconnected')
        this.setWakeLock(false)
      })

      this.phone.conn.on('error', err => {
        console.error('error in call', err)
      })
    },

    keyDown(key) {
      if (this.ongoingCall) {
        this.phone.conn.sendDigits(key)
        return
      }

      this.number = `${this.number}${key}`
    },

    keypress(evt) {
      if (evt.keyCode === 13) {
        this.toggleCall()
      }
    },

    async setWakeLock(lock) {
      if (!navigator || !navigator.getWakeLock) {
        // No wake-lock functionality present in this browser
        console.debug('Browser has no wake-lock support')
        return
      }

      if (!this.wakeLock.obj) {
        this.wakeLock.obj = await navigator.getWakeLock('screen')
      }

      if (lock && !this.wakeLock.request) {
        this.wakeLock.request = this.wakeLock.obj.createRequest()
        this.announceStatus('Wake-lock aquired: Keeping display active...')
        return
      }

      if (!lock && this.wakeLock.request) {
        this.wakeLock.request.cancel()
        this.wakeLock.request = null
        this.announceStatus('Wake-lock disabled: Screen may sleep...')
      }
    },

    setupPhone() {
      this.backoff.current = Math.min(this.backoff.current * this.backoff.multiplier, this.backoff.max)
      const opts = {
        codecPreferences: ['opus', 'pcmu'],
        fakeLocalDTMF: true,
      }

      if (this.phone.device) {
        this.phone.device.destroy()
      }

      axios.get(config.capabilityTokenURL, {
        headers: {
          authorization: `Bearer ${config.capabilityTokenAuth}`,
        },
      })
        .then(resp => {
          this.phone.device = new Device(resp.data.token, opts)

          this.phone.device.on('registered', () => {
            this.backoff.current = this.backoff.initial
            this.phone.registered = true
            this.announceStatus('Device registered')
          })
          this.phone.device.on('error', err => console.error(err))


          this.phone.device.on('incoming', call => {
            this.announceStatus(`Incoming call from ${call.parameters.From}...`, false)
            this.handleCall(call)
          })

          this.phone.device.on('unregistered', () => {
            this.phone.registered = false
            this.announceStatus('Phone unregistered, reconnecting...')
            window.setTimeout(() => this.setupPhone(), this.backoff.current)
          })

          this.phone.device.register()
        })
        .catch(err => console.error(err))
    },

    toggleCall() {
      if (this.pendingCall) {
        this.phone.conn.accept()
        return
      }

      if (this.ongoingCall) {
        this.phone.device.disconnectAll()
        return
      }

      // handle incoming

      if (this.number) {
        this.announceStatus(`Dialing ${this.number}...`)
        this.phone.device.connect({
          params: {
            To: this.number,
          },
        })
          .then(call => this.handleCall(call))
      }
    },
  },

  mounted() {
    window.setInterval(() => {
      this.now = new Date()
    }, 250)
    this.announceStatus('Phone loaded...')
  },

  name: 'BrowserPhoneApp',
}
</script>

<style scoped>
.btn-lg {
  font-size: 2rem;
  height: 2em;
  width: 2em;
}
input.form-control-lg {
  font-size: 2rem;
}
.number {
  background-color: transparent;
  color: #fff;
}
</style>
