import Vue from "vue/dist/vue.esm.js";
import Vuex from "vuex";
import VueRouter from "vue-router";
import Todo from "../components/todo-list.vue";
import Shortcut from "../components/shortcut-list.vue";
import Label from "../components/label-list.vue";
import UserEdit from "../components/user-edit.vue";
import PasswordEdit from "../components/password-edit.vue";
import Login from "../components/login-form.vue";
import Signup from "../components/signup-form.vue";
import Store from "../packs/store";

Vue.use(VueRouter);
Vue.use(Vuex);

function cookieStatus() {
  const cookie_user_id = document.cookie.replace(
    /(?:(?:^|.*;\s*)user_id\s*\=\s*([^;]*).*$)|^.*$/,
    "$1"
  );
  const cookie_remember_token = document.cookie.replace(
    /(?:(?:^|.*;\s*)remember_token\s*\=\s*([^;]*).*$)|^.*$/,
    "$1"
  );
  return cookie_user_id != "" && cookie_remember_token != "";
}

function getCurrentUser() {
  return Store.getters.getCurrentUser;
}

function login(to, from, next) {
  Store.dispatch("setToggleCloseAction");
  if (cookieStatus()) {
    if (getCurrentUser() == null || getCurrentUser().id == undefined) {
      Store.dispatch("currentUserAction").then(() => {
        next();
      });
    } else {
      next();
    }
  } else {
    next({ path: "/login" });
  }
}

function logout(to, from, next) {
  Store.dispatch("setToggleCloseAction");
  if (cookieStatus()) {
    next({ path: "/" });
  } else {
    if (getCurrentUser() == null || getCurrentUser().id == undefined) {
      next();
    } else {
      Store.dispatch("logoutAction").then(() => {
        next();
      });
    }
  }
}

export default new VueRouter({
  mode: "history",
  routes: [
    {
      path: "/",
      component: Todo,
      name: "todos",
      beforeEnter: login
    },
    {
      path: "/shortcuts",
      component: Shortcut,
      name: "shortcuts",
      beforeEnter: login
    },
    {
      path: "/labels",
      component: Label,
      name: "labels",
      beforeEnter: login
    },
    {
      path: "/user/:userId/edit",
      component: UserEdit,
      name: "user_edit",
      beforeEnter: login
    },
    {
      path: "/password/:userId/edit",
      component: PasswordEdit,
      name: "password_edit",
      beforeEnter: login
    },
    {
      path: "/login",
      component: Login,
      name: "login",
      beforeEnter: logout
    },
    {
      path: "/signup",
      component: Signup,
      name: "signup",
      beforeEnter: logout
    }
    // {
    //   path: "/password_resets/new",
    //   component: PasswordNew,
    //   name: "password_resets_new",
    //   beforeEnter: logout
    // },
    // {
    //   path: "/password_resets/:userId/edit",
    //   component: PasswordEdit,
    //   name: "password_resets_edit",
    //   beforeEnter: logout
    // }
    // { path: "*", component: NotFoundComponent }
  ]
});
