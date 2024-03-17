// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails";
import "controllers";

import "jquery";
import "@rails/ujs";

import "@popperjs/core";
import "bootstrap";

import { Datepicker } from "vanillajs-datepicker";

import "select2";

/**
 * Romanian translation for bootstrap-datepicker
 * Cristian Vasile <cristi.mie@gmail.com>
 */
Datepicker.locales.ro = {
  days: ["Duminică", "Luni", "Marţi", "Miercuri", "Joi", "Vineri", "Sâmbătă"],
  daysShort: ["Dum", "Lun", "Mar", "Mie", "Joi", "Vin", "Sâm"],
  daysMin: ["Du", "Lu", "Ma", "Mi", "Jo", "Vi", "Sâ"],
  months: [
    "Ianuarie",
    "Februarie",
    "Martie",
    "Aprilie",
    "Mai",
    "Iunie",
    "Iulie",
    "August",
    "Septembrie",
    "Octombrie",
    "Noiembrie",
    "Decembrie",
  ],
  monthsShort: [
    "Ian",
    "Feb",
    "Mar",
    "Apr",
    "Mai",
    "Iun",
    "Iul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
  ],
  today: "Astăzi",
  clear: "Șterge",
  weekStart: 1,
  format: "dd.mm.yyyy",
};

document.documentElement.addEventListener("turbo:load", () => {
  jQuery("input[data-datepicker]").each(function () {
    this.placeholder = "zz.ll.aaaa";

    new Datepicker(this, {
      buttonClass: "btn",
      language: "ro",
      minDate: this.dataset.minDate,
      maxDate: this.dataset.maxDate,
    });
  });

  $("select[data-use-select2]").each(function () {
    const selectBox = this;
    $(selectBox).select2();
    $.data(selectBox).select2.on("focus", function () {
      $(selectBox).select2("open");
    });
  });

  // We used to allow the selection of projects only for expenditures associated to "Research" financing sources,
  // but this is not the case anymore.
  // $("select#expenditure_financing_source_id").on(
  //   "select2:select",
  //   function (e) {
  //     const projectCategorySelect = $("select#expenditure_project_category_id");
  //
  //     const selectedFinancingSourceId = e.target.value;
  //     const desiredFinancingSourceId = projectCategorySelect
  //       .data("enable-for-financing-source-id")
  //       .toString();
  //
  //     if (desiredFinancingSourceId === selectedFinancingSourceId) {
  //       projectCategorySelect.prop("disabled", false);
  //     } else {
  //       projectCategorySelect.prop("disabled", true);
  //     }
  //   },
  // );
});
